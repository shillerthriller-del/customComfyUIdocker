#!/bin/bash
set -e

echo "=========================================="
echo "ComfyUI Startup Script"
echo "=========================================="

# Network volume mount point
NETWORK_VOLUME="/workspace"

# Directories to symlink from network volume
SYMLINK_DIRS=("models" "output" "input" "user")

# Create symlinks to network volume
echo "Setting up symlinks to network volume..."
for dir in "${SYMLINK_DIRS[@]}"; do
    SOURCE="$NETWORK_VOLUME/ComfyUI/$dir"
    TARGET="/app/ComfyUI/$dir"
    
    if [ -d "$SOURCE" ]; then
        # Remove existing directory/symlink in container
        rm -rf "$TARGET"
        # Create symlink
        ln -sf "$SOURCE" "$TARGET"
        echo "  ✓ Linked $dir -> $SOURCE"
    else
        echo "  ⚠ Warning: $SOURCE not found on network volume"
        # Create empty directory if it doesn't exist
        mkdir -p "$TARGET"
    fi
done

# Ensure output directory exists
mkdir -p "$NETWORK_VOLUME/ComfyUI/output"

# Optional: Update custom nodes on startup (uncomment if desired)
# echo "Updating custom nodes..."
# cd /app/ComfyUI/custom_nodes/comfyui-manager && git pull
# cd /app/ComfyUI/custom_nodes/ComfyUI-GGUF && git pull

# Print GPU info
echo ""
echo "=========================================="
echo "GPU Information:"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
echo "=========================================="

pip install jupyterlab -q
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' &

# Print connection info
echo ""
echo "=========================================="
echo "ComfyUI starting on port 8188"
echo ""
echo "For Krita AI Diffusion, use:"
echo "  URL: http://<your-pod-ip>:8188"
echo "  Or via RunPod proxy: https://<pod-id>-8188.proxy.runpod.net"
echo "=========================================="
echo ""

# Start ComfyUI
exec python -u main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --preview-method auto 2>&1
