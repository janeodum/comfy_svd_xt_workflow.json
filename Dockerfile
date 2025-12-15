# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.0-base

# ---- system deps (git for cloning nodes, ffmpeg for video writing, curl for debugging) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# 1) Install custom nodes: VideoHelperSuite (adds VHS_VideoCombine)
# -------------------------------------------------------------------
# IMPORTANT: ComfyUI in this image is at /comfyui
RUN mkdir -p /comfyui/custom_nodes \
  && cd /comfyui/custom_nodes \
  && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

# If the node has python deps, install them (safe even if empty/no-op)
RUN if [ -f /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt ]; then \
      pip install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt ; \
    fi

# -------------------------------------------------------------------
# 1b) Install Flux NF4 loader node + deps (CheckpointLoaderNF4)
# -------------------------------------------------------------------
RUN cd /comfyui/custom_nodes \
  && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git

# bitsandbytes is required for NF4 checkpoints
RUN pip install --no-cache-dir bitsandbytes

# -------------------------------------------------------------------
# 2) Download Wan 2.1 models (your existing lines)
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
# 3) Add Flux LoRA (Canopus Pixar 3D) into models/loras
# -------------------------------------------------------------------
# NOTE: The file name in the repo might not be exactly this.
# If the build fails with 404, open the HF repo "Files and versions"Canopus-Pixar-3D-Flux-LoRA
# and replace the URL + filename with the real one.
RUN comfy model download \
  --url https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
  --relative-path models/loras \
  --filename Canopus-Pixar-3D-FluxDev-LoRA.safetensors

# -------------------------------------------------------------------
# 4) Add Flux checkpoint (flux1-dev-bnb-nf4v2.safetensors)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/lllyasviel/flux1-dev-bnb-nf4/resolve/main/flux1-dev-bnb-nf4-v2.safetensors  \
  --relative-path models/checkpoints \
  --filename flux1-dev-bnb-nf4-v2.safetensors

# -------------------------------------------------------------------
# 5) Optional: copy inputs
# -------------------------------------------------------------------
# COPY input/ /comfyui/input/

# Done. ComfyUI will auto-load custom_nodes at startup.