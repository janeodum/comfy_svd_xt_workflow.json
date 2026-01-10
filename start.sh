#!/bin/bash
set -e

echo "🚀 Omnnia Worker Starting..."

if [ -d "/runpod-volume/models" ]; then
    VOLUME_PATH="/runpod-volume"
    echo "📦 Detected: Serverless (runpod-volume)"
elif [ -d "/workspace/models" ]; then
    VOLUME_PATH="/workspace"
    echo "📦 Detected: GPU Pod (workspace)"
else
    echo "⚠️ No network volume found!"
    exec python -u /rp_handler.py
fi

# Link custom nodes
echo "🔗 Linking custom nodes..."
if [ -d "$VOLUME_PATH/custom_nodes" ]; then
    for node in $VOLUME_PATH/custom_nodes/*; do
        if [ -d "$node" ]; then
            nodename=$(basename "$node")
            rm -rf "/comfyui/custom_nodes/$nodename"
            ln -sf "$node" "/comfyui/custom_nodes/$nodename"
            echo "  ✅ Linked: $nodename"
        fi
    done
fi

# Copy patched model.py if exists
if [ -f "$VOLUME_PATH/model_patch.py" ]; then
    cp "$VOLUME_PATH/model_patch.py" /comfyui/comfy/ldm/flux/model.py
    echo "  ✅ Patched model.py"
fi

# Link models
echo "🔗 Linking models..."
ln -sf $VOLUME_PATH/models/checkpoints /comfyui/models/ 2>/dev/null
ln -sf $VOLUME_PATH/models/diffusion_models /comfyui/models/ 2>/dev/null
ln -sf $VOLUME_PATH/models/text_encoders /comfyui/models/ 2>/dev/null
ln -sf $VOLUME_PATH/models/clip_vision /comfyui/models/ 2>/dev/null
ln -sf $VOLUME_PATH/models/vae /comfyui/models/ 2>/dev/null
ln -sf $VOLUME_PATH/models/loras /comfyui/models/ 2>/dev/null
ln -sf $VOLUME_PATH/models/xlabs /comfyui/models/ 2>/dev/null

echo "✅ Ready!"
exec python -u /rp_handler.py