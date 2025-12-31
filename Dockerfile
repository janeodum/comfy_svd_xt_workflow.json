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
# 1b) Custom nodes: VideoOutputBridge (maps videos into RunPod artifacts)
# -------------------------------------------------------------------
RUN cd /comfyui/custom_nodes \
  && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git
 
RUN if [ -f /comfyui/custom_nodes/ComfyUI-VideoOutputBridge/requirements.txt ]; then \
       pip install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-VideoOutputBridge/requirements.txt ; \
     fi
     
# -------------------------------------------------------------------
# 2) Custom nodes: NF4 loader (CheckpointLoaderNF4) + deps
# -------------------------------------------------------------------
RUN cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git

RUN pip install --no-cache-dir bitsandbytes

# -------------------------------------------------------------------
# 3) Wan 2.1 models (unchanged)
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
# 4) Flux NF4 checkpoint (this is what your workflow is failing on)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/lllyasviel/flux1-dev-bnb-nf4/resolve/main/flux1-dev-bnb-nf4-v2.safetensors \
  --relative-path models/checkpoints \
  --filename flux1-dev-bnb-nf4-v2.safetensors

RUN comfy model download \
  --url https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors \
  --relative-path models/checkpoints \
  --filename flux1-dev-fp8.safetensors
# -------------------------------------------------------------------
# 5) Flux text encoders + VAE (ae) - needed for Flux workflows
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
# 6) Pixar-ish Flux LoRA (ensure filename is exact)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
  --relative-path models/loras \
  --filename Canopus-Pixar-3D-FluxDev-LoRA.safetensors

# -------------------------------------------------------------------
# 7) Sanity checks during build (fail fast if missing)
# -------------------------------------------------------------------
RUN ls -lah /comfyui/models/checkpoints \
 && test -f /comfyui/models/checkpoints/flux1-dev-bnb-nf4-v2.safetensors