#!/bin/bash
echo "🔗 Omnnia: Linking Models from Persistent Volume..."

# Create the folder structure inside the container
mkdir -p /comfyui/models/clip_vision /comfyui/models/loras /comfyui/models/clip

# Link the CLIP Vision you verified exists
if [ -f "/runpod-volume/models/clip_vision/clip_vision_h.safetensors" ]; then
    ln -sf /runpod-volume/models/clip_vision/clip_vision_h.safetensors /comfyui/models/clip_vision/
    echo "✅ Linked CLIP Vision"
fi

# Link the Pixar LoRA you verified exists
if [ -f "/runpod-volume/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors" ]; then
    ln -sf /runpod-volume/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors /comfyui/models/loras/
    echo "✅ Linked Pixar LoRA"
fi

# Link the Wan CLIP you verified exists
if [ -f "/runpod-volume/models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    ln -sf /runpod-volume/models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors /comfyui/models/clip/
    echo "✅ Linked Wan CLIP"
fi

echo "🚀 Symlinking complete."