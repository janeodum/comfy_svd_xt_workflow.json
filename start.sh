#!/bin/bash
set -e

echo "🚀 Omnnia Worker Starting..."

# Detect volume path
if [ -d "/runpod-volume/models" ]; then
    VOLUME_PATH="/runpod-volume"
    echo "📦 Detected: Serverless (runpod-volume)"
elif [ -d "/workspace/models" ]; then
    VOLUME_PATH="/workspace"
    echo "📦 Detected: GPU Pod (workspace)"
else
    echo "⚠️ No network volume found! Models must exist in container."
    exec python -u /rp_handler.py
fi

echo "🔗 Linking models from $VOLUME_PATH..."

# Wipe local model dirs and symlink to volume
link_models() {
    local src="$1"
    local dst="$2"
    
    if [ -d "$src" ] || [ -f "$src" ]; then
        rm -rf "$dst"
        ln -sf "$src" "$dst"
        echo "  ✅ Linked: $dst -> $src"
    else
        echo "  ⚠️ Missing: $src"
    fi
}

# Link all model directories
link_models "$VOLUME_PATH/models/checkpoints" "/comfyui/models/checkpoints"
link_models "$VOLUME_PATH/models/diffusion_models" "/comfyui/models/diffusion_models"
link_models "$VOLUME_PATH/models/text_encoders" "/comfyui/models/text_encoders"
link_models "$VOLUME_PATH/models/clip_vision" "/comfyui/models/clip_vision"
link_models "$VOLUME_PATH/models/vae" "/comfyui/models/vae"
link_models "$VOLUME_PATH/models/loras" "/comfyui/models/loras"
link_models "$VOLUME_PATH/models/xlabs" "/comfyui/models/xlabs"

# Also link clip directory if exists (for umt5)
if [ -d "$VOLUME_PATH/models/clip" ]; then
    link_models "$VOLUME_PATH/models/clip" "/comfyui/models/clip"
fi

echo "🎉 Model linking complete!"
echo ""
echo "📂 Model directories:"
ls -la /comfyui/models/

echo ""
echo "🚀 Starting ComfyUI worker..."
exec python -u /rp_handler.py