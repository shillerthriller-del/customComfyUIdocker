#!/bin/bash
# ==============================================================================
# RunPod Idle GPU Monitor (v2 — spike detection)
# Samples GPU every 10s, tracks peak over 5min windows.
# Any spike above threshold resets the idle counter.
# Stops pod only after sustained zero-activity period.
# ==============================================================================

IDLE_TIMEOUT_MINUTES="${IDLE_TIMEOUT_MINUTES:-60}"
GPU_IDLE_THRESHOLD="${GPU_IDLE_THRESHOLD:-5}"
SAMPLE_INTERVAL=10       # seconds between GPU samples
WINDOW_SECONDS=300       # 5 min evaluation window
SAMPLES_PER_WINDOW=$(( WINDOW_SECONDS / SAMPLE_INTERVAL ))  # 30 samples
CHECKS_NEEDED=$(( IDLE_TIMEOUT_MINUTES * 60 / WINDOW_SECONDS ))  # 12 windows

IDLE_COUNT=0

# ANSI colors (match start.sh style)
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[IDLE-MONITOR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[IDLE-MONITOR]${NC} $1"; }
log_alert() { echo -e "${RED}[IDLE-MONITOR]${NC} $1"; }

# Sanity checks
if ! command -v nvidia-smi &> /dev/null; then
    log_warn "nvidia-smi not found — idle monitor disabled."
    exit 0
fi

if ! command -v runpodctl &> /dev/null; then
    log_warn "runpodctl not found — idle monitor disabled (not on RunPod?)."
    exit 0
fi

if [ -z "${RUNPOD_POD_ID:-}" ]; then
    log_warn "RUNPOD_POD_ID not set — idle monitor disabled."
    exit 0
fi

log "Started (v2 spike detection)."
log "Sampling GPU every ${SAMPLE_INTERVAL}s, evaluating peak every $((WINDOW_SECONDS / 60))min."
log "Any spike above ${GPU_IDLE_THRESHOLD}% resets the counter."
log "Pod stops after ${IDLE_TIMEOUT_MINUTES}min of zero activity (${CHECKS_NEEDED} consecutive idle windows)."

# Initial grace period — let ComfyUI finish loading
sleep "$WINDOW_SECONDS"

while true; do
    # Sample GPU for one full window, track the peak
    PEAK=0
    for (( i=0; i<SAMPLES_PER_WINDOW; i++ )); do
        GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')

        if [ -n "$GPU_UTIL" ] && [ "$GPU_UTIL" -gt "$PEAK" ] 2>/dev/null; then
            PEAK=$GPU_UTIL
        fi

        sleep "$SAMPLE_INTERVAL"
    done

    # Evaluate the window
    if [ "$PEAK" -ge "$GPU_IDLE_THRESHOLD" ]; then
        if [ "$IDLE_COUNT" -gt 0 ]; then
            log "GPU spike detected (peak ${PEAK}%) — resetting idle counter."
        else
            log "GPU active (peak ${PEAK}%) — all good."
        fi
        IDLE_COUNT=0
    else
        IDLE_COUNT=$((IDLE_COUNT + 1))
        ELAPSED=$((IDLE_COUNT * WINDOW_SECONDS / 60))
        log "No GPU spikes (peak ${PEAK}%) — idle for ~${ELAPSED}/${IDLE_TIMEOUT_MINUTES} min (${IDLE_COUNT}/${CHECKS_NEEDED} windows)"
    fi

    if [ "$IDLE_COUNT" -ge "$CHECKS_NEEDED" ]; then
        log_alert "=================================================="
        log_alert "  No GPU activity for ${IDLE_TIMEOUT_MINUTES}+ minutes."
        log_alert "  Stopping pod ${RUNPOD_POD_ID} to save credits."
        log_alert "=================================================="
        runpodctl stop pod "$RUNPOD_POD_ID"
        exit 0
    fi
done
