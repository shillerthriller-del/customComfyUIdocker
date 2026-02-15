#!/bin/bash
set -euo pipefail

# ==============================================================================
# ComfyUI Startup Script for RunPod
# ==============================================================================

# Configuration
NETWORK_VOLUME="${NETWORK_VOLUME:-/workspace}"
COMFYUI_PATH="${COMFYUI_PATH:-/app/ComfyUI}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
ENABLE_JUPYTER="${ENABLE_JUPYTER:-true}"

# Directories to symlink from network volume
SYMLINK_DIRS=("models" "output" "input" "user")

# ANSI colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper functions
# ==============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Cleanup function for graceful shutdown
cleanup() {
    log_info "Shutting down..."
    
    # Kill JupyterLab if running
    if [ -n "${JUPYTER_PID:-}" ] && kill -0 "$JUPYTER_PID" 2>/dev/null; then
        log_info "Stopping JupyterLab (PID: $JUPYTER_PID)"
        kill -TERM "$JUPYTER_PID" 2>/dev/null || true
        wait "$JUPYTER_PID" 2>/dev/null || true
    fi
    
    log_info "Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGHUP

# ==============================================================================
# Startup banner
# ==============================================================================
echo ""
echo "=========================================="
echo "  ComfyUI for RunPod + Krita AI Diffusion"
echo "  CUDA 12.8 / Blackwell Ready"
echo "=========================================="
echo ""

# ==============================================================================
# GPU Information
# ==============================================================================
log_info "Detecting GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || echo "Unknown")
    log_success "GPU: $GPU_INFO"
    
    # Show CUDA version
    CUDA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    log_info "Driver version: $CUDA_VERSION"
else
    log_warning "nvidia-smi not found - running without GPU?"
fi

# ==============================================================================
# Wait for network volume (RunPod can be slow to mount)
# ==============================================================================
log_info "Waiting for network volume..."
WAIT_COUNT=0
MAX_WAIT=30

while [ ! -d "$NETWORK_VOLUME" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    log_warning "Network volume not ready, waiting... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ ! -d "$NETWORK_VOLUME" ]; then
    log_warning "Network volume '$NETWORK_VOLUME' not found after ${MAX_WAIT}s - using local directories"
fi

# ==============================================================================
# Network volume symlinks
# ==============================================================================
log_info "Setting up network volume symlinks..."

if [ -d "$NETWORK_VOLUME" ]; then
    for dir in "${SYMLINK_DIRS[@]}"; do
        SOURCE="$NETWORK_VOLUME/ComfyUI/$dir"
        TARGET="$COMFYUI_PATH/$dir"
        
        # Create source directory on network volume if it doesn't exist
        if [ ! -d "$SOURCE" ]; then
            log_info "Creating $SOURCE on network volume..."
            mkdir -p "$SOURCE"
        fi
        
        # Remove existing directory/symlink in container
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
            rm -rf "$TARGET"
        fi
        
        # Create symlink
        ln -sf "$SOURCE" "$TARGET"
        
        # Verify symlink works
        if [ -d "$TARGET" ]; then
            log_success "Linked: $dir -> $SOURCE"
        else
            log_error "Failed to link $dir - symlink exists but target not accessible"
        fi
    done
else
    log_warning "Using local directories (no network volume)"
fi

# Ensure output directory exists and is writable
OUTPUT_DIR="$COMFYUI_PATH/output"
if [ -d "$OUTPUT_DIR" ]; then
    if touch "$OUTPUT_DIR/.write_test" 2>/dev/null; then
        rm -f "$OUTPUT_DIR/.write_test"
        log_success "Output directory is writable"
    else
        log_warning "Output directory is not writable!"
    fi
fi

# ==============================================================================
# Optional: Update custom nodes (uncomment if desired)
# ==============================================================================
# log_info "Updating custom nodes..."
# cd "$COMFYUI_PATH/custom_nodes/comfyui-manager" && git pull --quiet 2>/dev/null || true
# cd "$COMFYUI_PATH/custom_nodes/ComfyUI-GGUF" && git pull --quiet 2>/dev/null || true

# ==============================================================================
# Start JupyterLab (background)
# ==============================================================================
if [ "$ENABLE_JUPYTER" = "true" ]; then
    log_info "Starting JupyterLab on port $JUPYTER_PORT..."
    
    jupyter lab \
        --ip=0.0.0.0 \
        --port="$JUPYTER_PORT" \
        --no-browser \
        --allow-root \
        --ServerApp.token='' \
        --ServerApp.password='' \
        --ServerApp.allow_origin='*' \
        --ServerApp.root_dir="$NETWORK_VOLUME" \
        > /tmp/jupyter.log 2>&1 &
    
    JUPYTER_PID=$!
    
    # Brief wait to check if it started
    sleep 2
    if kill -0 "$JUPYTER_PID" 2>/dev/null; then
        log_success "JupyterLab started (PID: $JUPYTER_PID)"
    else
        log_warning "JupyterLab may have failed to start - check /tmp/jupyter.log"
    fi
fi

# ==============================================================================
# Connection information
# ==============================================================================
echo ""
echo "=========================================="
echo "  Connection Information"
echo "=========================================="
echo ""
echo "  ComfyUI:     http://localhost:$COMFYUI_PORT"
echo "  JupyterLab:  http://localhost:$JUPYTER_PORT"
echo ""
echo "  For Krita AI Diffusion, use:"
echo "    URL: http://<your-pod-ip>:$COMFYUI_PORT"
echo "    Or:  https://<pod-id>-$COMFYUI_PORT.proxy.runpod.net"
echo ""
echo "=========================================="
echo ""

# ==============================================================================
# Start ComfyUI (foreground)
# ==============================================================================
log_info "Starting ComfyUI on port $COMFYUI_PORT..."

cd "$COMFYUI_PATH"

# ComfyUI arguments
COMFYUI_ARGS=(
    --listen 0.0.0.0
    --port "$COMFYUI_PORT"
    --enable-cors-header
    --preview-method auto
)

# Optional: Add extra memory optimization for large models
# COMFYUI_ARGS+=(--lowvram)
# COMFYUI_ARGS+=(--gpu-only)

# Execute ComfyUI - use exec to replace shell process (proper signal handling)
exec python -u main.py "${COMFYUI_ARGS[@]}" 2>&1
