#!/bin/bash
# download_models.sh - Downloads models only if they don't exist

set -e

MODEL_DIR="${COMFY_MODEL_DIR:-/comfyui/models}"

download_if_missing() {
    local url="$1"
    local dest="$2"
    
    if [ ! -f "$dest" ]; then
        echo "⬇️  Downloading $(basename $dest)..."
        curl -L --progress-bar -o "$dest" "$url"
        echo "✅ Downloaded $(basename $dest)"
    else
        echo "✅ $(basename $dest) already exists"
    fi
}

echo "🔍 Checking models..."

# Flux checkpoint
download_if_missing \
    "https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors" \
    "$MODEL_DIR/checkpoints/flux1-dev-fp8.safetensors"

# Flux text encoders
download_if_missing \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$MODEL_DIR/text_encoders/clip_l.safetensors"

download_if_missing \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "$MODEL_DIR/text_encoders/t5xxl_fp8_e4m3fn.safetensors"

# Flux VAE
download_if_missing \
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "$MODEL_DIR/vae/ae.safetensors"

# Wan 2.1 models
download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$MODEL_DIR/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "$MODEL_DIR/vae/wan_2.1_vae.safetensors"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors" \
    "$MODEL_DIR/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "$MODEL_DIR/clip_vision/clip_vision_h.safetensors"

# LoRA
download_if_missing \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors" \
    "$MODEL_DIR/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# PuLID (skip for now if you want faster startup - add later)
download_if_missing \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors" \
    "$MODEL_DIR/pulid/pulid_flux_v0.9.1.safetensors"

echo "✅ All models ready!"