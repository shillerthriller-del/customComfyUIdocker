# ComfyUI Docker for RunPod

Optimized Docker image for ComfyUI with Flux, ControlNet, and Krita AI Diffusion support.
Designed for Blackwell GPUs (B200, RTX 5090) with CUDA 12.8.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Docker Image (~15GB)                                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ - Ubuntu 22.04 + CUDA 12.8 runtime                      │ │
│ │ - Python 3.11                                           │ │
│ │ - PyTorch + cu128                                       │ │
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
│ Network Volume /workspace                                   │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /workspace/ComfyUI/models/                              │ │
│ │   ├── checkpoints/                                      │ │
│ │   ├── diffusion_models/                                 │ │
│ │   ├── controlnet/                                       │ │
│ │   ├── text_encoders/                                    │ │
│ │   ├── loras/                                            │ │
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

## RunPod Template Configuration

### Container Image
```
yourusername/comfyui-flux:v1
```

### Expose HTTP Ports
```
8188,8888
```

### Volume Mount
```
/workspace
```

## Connecting Krita AI Diffusion

1. Start pod with this template
2. Wait for ComfyUI to initialize (check logs)
3. In Krita AI Diffusion settings:
   - **URL**: `https://<pod-id>-8188.proxy.runpod.net`
   - Or if using direct IP: `http://<pod-ip>:8188`

## Downloading Models

### Set your API tokens

```bash
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxx"
export CIVITAI_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxx"
```

### Hugging Face

```bash
# Keep original filename
curl -L -H "Authorization: Bearer $HF_TOKEN" \
  "https://huggingface.co/REPO/resolve/main/model.safetensors" \
  -O

# Custom filename
curl -L -H "Authorization: Bearer $HF_TOKEN" \
  "https://huggingface.co/REPO/resolve/main/model.safetensors" \
  -o custom_name.safetensors
```

### CivitAI

```bash
# Keep original filename
curl -L -J \
  "https://civitai.com/api/download/models/MODEL_VERSION_ID?token=$CIVITAI_TOKEN" \
  -O

# Custom filename
curl -L \
  "https://civitai.com/api/download/models/MODEL_VERSION_ID?token=$CIVITAI_TOKEN" \
  -o custom_name.safetensors
```

Replace `MODEL_VERSION_ID` with the ID from the CivitAI download URL.

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
Should show `12.8`

### Custom node errors
Update nodes manually:
```bash
cd /app/ComfyUI/custom_nodes/comfyui-manager
git pull
```

## Version History

- **v2.0** - CUDA 12.8 for Blackwell GPUs (RTX 50xx)
- **v1.0** - Initial build
