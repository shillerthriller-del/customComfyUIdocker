# ComfyUI Docker for RunPod - Optimized for Blackwell (B200/RTX 5090)
# Designed to work with network volume for models

FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

LABEL maintainer="Max - Brigitte Ermel Joaillier"
LABEL description="ComfyUI with Flux + ControlNet + Krita AI Diffusion support"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# System dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# Create app directory
WORKDIR /app

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

WORKDIR /app/ComfyUI

# Install PyTorch with CUDA 13.0 support (for Blackwell)
RUN pip install --upgrade pip && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# Install ComfyUI requirements
RUN pip install -r requirements.txt

# Pin numpy to avoid opencv conflict
RUN pip install "numpy>=2.0.0,<2.3.0"

# Install additional dependencies that are commonly missing
RUN pip install \
    matplotlib \
    opencv-python-headless \
    onnxruntime-gpu \
    insightface \
    scikit-image \
    scipy

# Clone custom nodes
WORKDIR /app/ComfyUI/custom_nodes

# ComfyUI Manager
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git comfyui-manager

# GGUF support (for quantized models)
RUN git clone https://github.com/city96/ComfyUI-GGUF.git ComfyUI-GGUF

# IPAdapter
RUN git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git ComfyUI_IPAdapter_plus

# Inpaint nodes
RUN git clone https://github.com/Acly/comfyui-inpaint-nodes.git comfyui-inpaint-nodes

# Tooling nodes (for Krita AI Diffusion)
RUN git clone https://github.com/Acly/comfyui-tooling-nodes.git comfyui-tooling-nodes

# ControlNet preprocessors
RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git comfyui_controlnet_aux

# X-Flux
RUN git clone https://github.com/XLabs-AI/x-flux-comfyui.git x-flux-comfyui

# Install custom node dependencies
WORKDIR /app/ComfyUI/custom_nodes/comfyui_controlnet_aux
RUN pip install -r requirements.txt || true

WORKDIR /app/ComfyUI/custom_nodes/ComfyUI_IPAdapter_plus
RUN pip install -r requirements.txt || true

WORKDIR /app/ComfyUI/custom_nodes/ComfyUI-GGUF
RUN pip install -r requirements.txt || true

# Back to main directory
WORKDIR /app/ComfyUI

# Create startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Expose ComfyUI port
EXPOSE 8188

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8188/ || exit 1

# Start ComfyUI
CMD ["/app/start.sh"]
