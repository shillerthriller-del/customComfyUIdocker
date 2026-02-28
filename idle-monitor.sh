#!/bin/bash
# ==============================================================================
# RunPod Idle GPU Monitor
# Stops the pod after sustained GPU inactivity to avoid burning credits.
# Designed to run in background alongside ComfyUI.
# ==============================================================================

IDLE_TIMEOUT_MINUTES="${IDLE_TIMEOUT_MINUTES:-60}"
GPU_IDLE_THRESHOLD="${GPU_IDLE_THRESHOLD:-5}"
CHECK_INTERVAL=300  # seconds between checks (5 min)

# Calculate how many consecutive idle checks = timeout
CHECKS_NEEDED=$(( IDLE_TIMEOUT_MINUTES * 60 / CHECK_INTERVAL ))
IDLE_COUNT=0

# ANSI colors (match start.sh style)
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
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

log "Started. Will stop pod after ${IDLE_TIMEOUT_MINUTES}min of GPU usage below ${GPU_IDLE_THRESHOLD}%."
log "Checking every $((CHECK_INTERVAL / 60))min. Need ${CHECKS_NEEDED} consecutive idle checks."

# Initial grace period — let ComfyUI finish loading before monitoring
sleep "$CHECK_INTERVAL"

while true; do
    # Query GPU utilization (percentage, 0-100)
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')

    if [ -z "$GPU_UTIL" ]; then
        log_warn "Could not read GPU utilization — skipping this check."
        IDLE_COUNT=0
        sleep "$CHECK_INTERVAL"
        continue
    fi

    if [ "$GPU_UTIL" -lt "$GPU_IDLE_THRESHOLD" ]; then
        IDLE_COUNT=$((IDLE_COUNT + 1))
        ELAPSED=$((IDLE_COUNT * CHECK_INTERVAL / 60))
        log "GPU at ${GPU_UTIL}% — idle for ~${ELAPSED}/${IDLE_TIMEOUT_MINUTES} min (${IDLE_COUNT}/${CHECKS_NEEDED} checks)"
    else
        if [ "$IDLE_COUNT" -gt 0 ]; then
            log "GPU at ${GPU_UTIL}% — activity detected, resetting idle counter."
        fi
        IDLE_COUNT=0
    fi

    if [ "$IDLE_COUNT" -ge "$CHECKS_NEEDED" ]; then
        log_alert "=================================================="
        log_alert "  GPU idle for ${IDLE_TIMEOUT_MINUTES}+ minutes."
        log_alert "  Stopping pod ${RUNPOD_POD_ID} to save credits."
        log_alert "=================================================="
        runpodctl stop pod "$RUNPOD_POD_ID"
        exit 0
    fi

    sleep "$CHECK_INTERVAL"
done
