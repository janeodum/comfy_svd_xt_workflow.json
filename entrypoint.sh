#!/usr/bin/env bash
set -euo pipefail

MODELS_DIR="${MODELS_DIR:-/comfyui/models}"

download() {
  local url="$1"
  local out="$2"

  if [[ -f "$out" ]]; then
    echo "✅ exists: $out"
    return 0
  fi

  mkdir -p "$(dirname "$out")"
  echo "⬇️ downloading: $url"
  # aria2 is faster + resumes
  aria2c -x 16 -s 16 -k 1M -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
  echo "✅ downloaded: $out"
}

echo "=== Runtime model check ==="
echo "MODELS_DIR=$MODELS_DIR"
mkdir -p "$MODELS_DIR"

# ---- Flux checkpoint ----
download \
  "https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors" \
  "$MODELS_DIR/checkpoints/flux1-dev-fp8.safetensors"

# ---- Flux encoders ----
download \
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
  "$MODELS_DIR/text_encoders/clip_l.safetensors"

download \
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
  "$MODELS_DIR/text_encoders/t5xxl_fp8_e4m3fn.safetensors"

# ---- Flux VAE ----
download \
  "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
  "$MODELS_DIR/vae/ae.safetensors"

# ---- PuLID ----
download \
  "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors" \
  "$MODELS_DIR/pulid/pulid_flux_v0.9.1.safetensors"

# ---- Wan 2.1 ----
download \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "$MODELS_DIR/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
  "$MODELS_DIR/vae/wan_2.1_vae.safetensors"

download \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors" \
  "$MODELS_DIR/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors"

download \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
  "$MODELS_DIR/clip_vision/clip_vision_h.safetensors"

# ---- Pixar LoRA ----
download \
  "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors" \
  "$MODELS_DIR/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

echo "✅ All required models present."

# Hand off to the base image's normal startup (keeps compatibility)
exec /start.sh "$@"