FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

# ---- system deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# -------------------------------------------------------------------
# 1) Custom nodes: VideoHelperSuite (VHS_VideoCombine)
# -------------------------------------------------------------------
RUN mkdir -p /comfyui/custom_nodes \
 && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

RUN if [ -f /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt ]; then \
      pip install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt ; \
    fi

# -------------------------------------------------------------------
# 2) Wan 2.1 models (unchanged)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors \
  --relative-path models/text_encoders \
  --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors

RUN comfy model download \
  --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors \
  --relative-path models/vae \
  --filename wan_2.1_vae.safetensors

RUN comfy model download \
  --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors \
  --relative-path models/diffusion_models/Wan2.1 \
  --filename wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors

RUN comfy model download \
  --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors \
  --relative-path models/clip_vision \
  --filename clip_vision_h.safetensors

# -------------------------------------------------------------------
# 3) Flux checkpoint (NON-NF4) -> put in models/checkpoints
#    (This is the one your Flux workflow should load via CheckpointLoaderSimple)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev-fp8.safetensors \
  --relative-path models/checkpoints \
  --filename flux1-dev-fp8.safetensors

# -------------------------------------------------------------------
# 4) Flux text encoders + VAE (ae) - needed for Flux workflows
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/clip_l.safetensors \
  --relative-path models/text_encoders \
  --filename clip_l.safetensors

RUN comfy model download \
  --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/t5xxl_fp16.safetensors \
  --relative-path models/text_encoders \
  --filename t5xxl_fp16.safetensors

RUN comfy model download \
  --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors \
  --relative-path models/vae \
  --filename ae.safetensors

# -------------------------------------------------------------------
# 5) Pixar-ish Flux LoRA (ensure filename is exact in the repo)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-Flux-LoRA.safetensors \
  --relative-path models/loras \
  --filename Canopus-Pixar-3D-Flux-LoRA.safetensors

# -------------------------------------------------------------------
# 6) Sanity checks during build (fail fast if missing)
# -------------------------------------------------------------------
RUN echo "=== checkpoints ===" \
 && ls -lah /comfyui/models/checkpoints \
 && test -f /comfyui/models/checkpoints/flux1-dev-fp8.safetensors \
 && echo "=== loras ===" \
 && ls -lah /comfyui/models/loras \
 && test -f /comfyui/models/loras/Canopus-Pixar-3D-Flux-LoRA.safetensors