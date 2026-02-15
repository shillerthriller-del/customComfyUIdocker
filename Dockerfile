# ==============================================================================
# ComfyUI Docker Image for RunPod + Krita AI Diffusion
# Optimized for NVIDIA Blackwell (RTX 50xx) with CUDA 12.8
# Last updated: February 2026
# ==============================================================================

# CUDA 12.8 base image for Blackwell GPU support
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

# Metadata
LABEL maintainer="Max"
LABEL description="ComfyUI with Krita AI Diffusion support for RunPod (Blackwell/CUDA 12.8)"
LABEL version="2.1"

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # ComfyUI specific
    COMFYUI_PATH=/app/ComfyUI \
    # Torch settings for better GPU memory management
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# ==============================================================================
# Layer 1: System dependencies (rarely changes)
# ==============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    git \
    wget \
    curl \
    # OpenCV dependencies
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    # Useful for debugging
    htop \
    nano \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# ==============================================================================
# Layer 2: PyTorch 2.9.1 with CUDA 12.8 (stable + Blackwell compatible)
# Using Python 3.11 for maximum compatibility with custom nodes
# ==============================================================================
RUN pip install --no-cache-dir \
    torch==2.9.1 \
    torchvision==0.24.1 \
    torchaudio==2.9.1 \
    --index-url https://download.pytorch.org/whl/cu128

# ==============================================================================
# Layer 3: Common Python dependencies
# ==============================================================================
RUN pip install --no-cache-dir \
    # Core scientific stack
    numpy==1.26.4 \
    scipy \
    scikit-image \
    # Image processing
    opencv-python-headless \
    Pillow \
    # ML/AI libraries
    transformers \
    accelerate \
    safetensors \
    einops \
    # Networking
    aiohttp \
    requests \
    # Utilities
    tqdm \
    psutil \
    pyyaml \
    gitpython \
    matplotlib \
    uv \
    # JupyterLab for debugging
    jupyterlab

# xformers for memory-efficient attention (compatible with torch 2.9.1)
RUN pip install --no-cache-dir xformers==0.0.32.post1 || \
    pip install --no-cache-dir xformers || true

# ONNX Runtime GPU - for CUDA 12.x
RUN pip install --no-cache-dir onnxruntime-gpu || \
    pip install --no-cache-dir onnxruntime

# InsightFace (for face-related features)
RUN pip install --no-cache-dir insightface

# ==============================================================================
# Layer 4: Clone ComfyUI
# ==============================================================================
WORKDIR /app
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI \
    && cd /app/ComfyUI \
    && pip install --no-cache-dir -r requirements.txt

# ==============================================================================
# Layer 5: Custom nodes for Krita AI Diffusion
# ==============================================================================
WORKDIR /app/ComfyUI/custom_nodes

# --- REQUIRED by Krita AI Diffusion ---
# ComfyUI Manager (for easy node management)
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git comfyui-manager

# ControlNet Preprocessors (REQUIRED)
RUN git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux.git comfyui_controlnet_aux

# IP-Adapter (REQUIRED)
RUN git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git ComfyUI_IPAdapter_plus

# Inpaint nodes (REQUIRED)
RUN git clone --depth 1 https://github.com/Acly/comfyui-inpaint-nodes.git comfyui-inpaint-nodes

# External tooling nodes (REQUIRED)
RUN git clone --depth 1 https://github.com/Acly/comfyui-tooling-nodes.git comfyui-tooling-nodes

# --- OPTIONAL but recommended ---
# GGUF support for quantized models
RUN git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git ComfyUI-GGUF

# Nunchaku for svdq models (Flux optimization)
RUN git clone --depth 1 https://github.com/nunchaku-tech/ComfyUI-nunchaku.git ComfyUI-nunchaku || true

# X-Flux for advanced Flux workflows
RUN git clone --depth 1 https://github.com/XLabs-AI/x-flux-comfyui.git x-flux-comfyui || true

# ==============================================================================
# Layer 6: Install custom node dependencies
# ==============================================================================
RUN cd comfyui-manager && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../comfyui_controlnet_aux && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../ComfyUI_IPAdapter_plus && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../comfyui-inpaint-nodes && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../comfyui-tooling-nodes && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../ComfyUI-GGUF && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../ComfyUI-nunchaku && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true \
    && cd ../x-flux-comfyui && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true

# Clean up .git directories to reduce image size (~200MB savings)
RUN find /app/ComfyUI -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# ==============================================================================
# Layer 7: Startup script and final configuration
# ==============================================================================
WORKDIR /app/ComfyUI

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create default directories (will be replaced by symlinks at runtime)
RUN mkdir -p /app/ComfyUI/models \
             /app/ComfyUI/output \
             /app/ComfyUI/input \
             /app/ComfyUI/user

# Expose ports: ComfyUI (8188), JupyterLab (8888)
EXPOSE 8188 8888

# Healthcheck - verify ComfyUI is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8188/system_stats || exit 1

# Default command
CMD ["/app/start.sh"]
