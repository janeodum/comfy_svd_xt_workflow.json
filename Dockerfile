FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

# ---- system deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# -------------------------------------------------------------------
# 1) Custom nodes only (fast to clone)
# -------------------------------------------------------------------
RUN mkdir -p /comfyui/custom_nodes \
 && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

# Install Python dependencies
RUN pip install --no-cache-dir bitsandbytes insightface onnxruntime-gpu facexlib

# Install requirements from custom nodes
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
      [ -f "$req" ] && pip install --no-cache-dir -r "$req" || true; \
    done

# -------------------------------------------------------------------
# 2) Create model directories
# -------------------------------------------------------------------
RUN mkdir -p /comfyui/models/checkpoints \
    /comfyui/models/text_encoders \
    /comfyui/models/vae \
    /comfyui/models/clip_vision \
    /comfyui/models/diffusion_models/Wan2.1 \
    /comfyui/models/loras \
    /comfyui/models/pulid \
    /comfyui/models/clip \
    /comfyui/models/insightface/models/antelopev2

# -------------------------------------------------------------------
# 3) DOWNLOAD MODELS AT BUILD TIME
# This makes the image large (~25GB) but guarantees models are present
# -------------------------------------------------------------------

# Flux checkpoint (~12GB) - This is the main one causing the error
RUN curl -L --progress-bar -o /comfyui/models/checkpoints/flux1-dev-fp8.safetensors \
    "https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors"

# Flux text encoders
RUN curl -L --progress-bar -o /comfyui/models/text_encoders/clip_l.safetensors \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"

RUN curl -L --progress-bar -o /comfyui/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"

# Flux VAE
RUN curl -L --progress-bar -o /comfyui/models/vae/ae.safetensors \
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"

# PuLID model - Also causing error
RUN curl -L --progress-bar -o /comfyui/models/pulid/pulid_flux_v0.9.1.safetensors \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors"

# Wan 2.1 models for video generation
RUN curl -L --progress-bar -o /comfyui/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

RUN curl -L --progress-bar -o /comfyui/models/vae/wan_2.1_vae.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

RUN curl -L --progress-bar -o /comfyui/models/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors"

RUN curl -L --progress-bar -o /comfyui/models/clip_vision/clip_vision_h.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

# LoRA for Pixar style
RUN curl -L --progress-bar -o /comfyui/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# Verify models exist
RUN ls -la /comfyui/models/checkpoints/ && \
    ls -la /comfyui/models/pulid/ && \
    echo "✅ Models downloaded successfully"

ENV COMFY_MODEL_DIR=/comfyui/models