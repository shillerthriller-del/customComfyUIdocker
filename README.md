# ComfyUI Docker for RunPod

Optimized Docker image for ComfyUI with Flux, ControlNet, and Krita AI Diffusion support.
Designed for Blackwell GPUs (B200, RTX 5090) with CUDA 13.0.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Docker Image (~15GB)                                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ - Ubuntu 22.04 + CUDA 12.4 runtime                      │ │
│ │ - Python 3.11                                           │ │
│ │ - PyTorch 2.9.1+cu130                                   │ │
│ │ - ComfyUI core                                          │ │
│ │ - Custom nodes (pre-installed)                          │ │
│ │ - All pip dependencies                                  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                          │                                  │
│                    symlinks at startup                      │
│                          ▼                                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Network Volume /workspace (~195GB)                          │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /workspace/ComfyUI/models/                              │ │
│ │   ├── checkpoints/     (53GB)                           │ │
│ │   ├── diffusion_models/ (85GB)                          │ │
│ │   ├── controlnet/      (25GB)                           │ │
│ │   ├── text_encoders/   (17GB)                           │ │
│ │   ├── loras/           (6GB)                            │ │
│ │   └── ...                                               │ │
│ │ /workspace/ComfyUI/output/                              │ │
│ │ /workspace/ComfyUI/input/                               │ │
│ │ /workspace/ComfyUI/user/  (workflows, settings)         │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Custom Nodes Included

- **comfyui-manager** - Node management
- **ComfyUI-GGUF** - Quantized model support
- **ComfyUI_IPAdapter_plus** - IP Adapter
- **comfyui-inpaint-nodes** - Inpainting
- **comfyui-tooling-nodes** - Krita AI Diffusion support
- **comfyui_controlnet_aux** - ControlNet preprocessors
- **x-flux-comfyui** - Flux support

## Building the Image

### Option 1: Build locally and push to Docker Hub

```bash
# Build
docker build -t yourusername/comfyui-runpod:latest .

# Test locally (optional)
docker run --gpus all -p 8188:8188 yourusername/comfyui-runpod:latest

# Push to Docker Hub
docker login
docker push yourusername/comfyui-runpod:latest
```

### Option 2: Build on RunPod

Upload the Dockerfile and start.sh to a pod, then:

```bash
cd /path/to/dockerfile
docker build -t yourusername/comfyui-runpod:latest .
docker push yourusername/comfyui-runpod:latest
```

## RunPod Template Configuration

### Container Image
```
yourusername/comfyui-runpod:latest
```

### Docker Command (leave empty)
The image uses CMD in Dockerfile, no override needed.

### Expose HTTP Ports
```
8188
```

### Volume Mount
```
/workspace
```

### Environment Variables (optional)
```
PYTHONUNBUFFERED=1
```

## Network Volume Preparation

Before first use, ensure your network volume has this structure:

```
/workspace/
└── ComfyUI/
    ├── models/
    │   ├── checkpoints/
    │   ├── diffusion_models/
    │   ├── controlnet/
    │   ├── text_encoders/
    │   ├── loras/
    │   ├── vae/
    │   └── ...
    ├── output/
    ├── input/
    └── user/
```

If migrating from existing setup, your models are already in place.

## Connecting Krita AI Diffusion

1. Start pod with this template
2. Wait for ComfyUI to initialize (check logs)
3. In Krita AI Diffusion settings:
   - **URL**: `https://<pod-id>-8188.proxy.runpod.net`
   - Or if using direct IP: `http://<pod-ip>:8188`

## Cleanup: Remove venv from Network Volume

After switching to Docker, you can reclaim ~12GB by removing the old venv:

```bash
rm -rf /workspace/ComfyUI/venv
```

Keep the rest of the ComfyUI folder for models and user data.

## Troubleshooting

### Models not found
Check symlinks:
```bash
ls -la /app/ComfyUI/models
```
Should point to `/workspace/ComfyUI/models`

### CUDA version mismatch
Verify torch CUDA version:
```bash
python -c "import torch; print(torch.version.cuda)"
```
Should show `13.0`

### Custom node errors
Update nodes manually:
```bash
cd /app/ComfyUI/custom_nodes/comfyui-manager
git pull
```

## Version History

- **v1.0** - Initial build with cu130 support for Blackwell GPUs
