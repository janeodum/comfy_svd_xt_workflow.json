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
# NEW: PuLID for Flux (Identity Preservation)
# -------------------------------------------------------------------
RUN cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

# Install PuLID dependencies
RUN pip install --no-cache-dir insightface onnxruntime-gpu facexlib

# Download InsightFace models (required for face detection)
RUN mkdir -p /comfyui/models/insightface/models/antelopev2 \
 && cd /comfyui/models/insightface/models/antelopev2 \
 && curl -L -o 1k3d68.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx" \
 && curl -L -o 2d106det.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx" \
 && curl -L -o genderage.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx" \
 && curl -L -o glintr100.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx" \
 && curl -L -o scrfd_10g_bnkps.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx"

# Download PuLID model for Flux
RUN mkdir -p /comfyui/models/pulid \
 && comfy model download \
  --url https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors \
  --relative-path models/pulid \
  --filename pulid_flux_v0.9.1.safetensors

# Download EVA-CLIP (required by PuLID)
RUN mkdir -p /comfyui/models/clip \
 && comfy model download \
  --url https://huggingface.co/QuanSun/EVA-CLIP/resolve/main/EVA02_CLIP_L_336_psz14_s6B.pt \
  --relative-path models/clip \
  --filename EVA02_CLIP_L_336_psz14_s6B.pt

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
# 4) Flux NF4 checkpoint
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
# 5) Flux text encoders + VAE (ae)
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors \
  --relative-path models/text_encoders \
  --filename clip_l.safetensors

RUN comfy model download \
  --url https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors \
  --relative-path models/text_encoders \
  --filename t5xxl_fp8_e4m3fn.safetensors

RUN comfy model download \
  --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors \
  --relative-path models/vae \
  --filename ae.safetensors

# -------------------------------------------------------------------
# 6) Pixar-ish Flux LoRA
# -------------------------------------------------------------------
RUN comfy model download \
  --url https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
  --relative-path models/loras \
  --filename Canopus-Pixar-3D-FluxDev-LoRA.safetensors

# -------------------------------------------------------------------
# 7) Sanity checks during build
# -------------------------------------------------------------------
RUN ls -lah /comfyui/models/checkpoints \
 && test -f /comfyui/models/checkpoints/flux1-dev-fp8.safetensors \
 && test -f /comfyui/models/pulid/pulid_flux_v0.9.1.safetensors \
 && echo "✅ All models downloaded successfully"