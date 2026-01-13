FROM nvidia/cuda:12.4.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

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

WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI
WORKDIR /app/ComfyUI

RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

RUN pip install -r requirements.txt
RUN pip install "numpy>=2.0.0,<2.3.0"
RUN pip install matplotlib opencv-python-headless onnxruntime-gpu insightface scikit-image scipy
RUN pip install uv gitpython

WORKDIR /app/ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git comfyui-manager
RUN git clone https://github.com/city96/ComfyUI-GGUF.git ComfyUI-GGUF
RUN git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git ComfyUI_IPAdapter_plus
RUN git clone https://github.com/Acly/comfyui-inpaint-nodes.git comfyui-inpaint-nodes
RUN git clone https://github.com/Acly/comfyui-tooling-nodes.git comfyui-tooling-nodes
RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git comfyui_controlnet_aux
RUN git clone https://github.com/XLabs-AI/x-flux-comfyui.git x-flux-comfyui

WORKDIR /app/ComfyUI/custom_nodes/comfyui_controlnet_aux
RUN pip install -r requirements.txt || true

WORKDIR /app/ComfyUI/custom_nodes/ComfyUI_IPAdapter_plus
RUN pip install -r requirements.txt || true

WORKDIR /app/ComfyUI/custom_nodes/ComfyUI-GGUF
RUN pip install -r requirements.txt || true

WORKDIR /app/ComfyUI
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 8188
CMD ["/app/start.sh"]
