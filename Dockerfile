FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

# ---- 1) Install aria2 for high-speed parallel downloads ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# ---- 2) Custom nodes and Python deps (Remains the same) ----
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

RUN pip install --no-cache-dir bitsandbytes insightface onnxruntime-gpu facexlib
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
      [ -f "$req" ] && pip install --no-cache-dir -r "$req" || true; \
    done

# ---- 3) SEQUENTIAL MODEL DOWNLOADS (Final Fix for Exit Code 24) ----
# We create the directories first
RUN mkdir -p /comfyui/models/checkpoints /comfyui/models/text_encoders /comfyui/models/vae \
    /comfyui/models/diffusion_models/Wan2.1 /comfyui/models/loras /comfyui/models/pulid \
    /comfyui/models/clip /comfyui/models/insightface/models/antelopev2

# Each RUN command below starts a fresh process, resetting file descriptors to 0.
RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/checkpoints "https://huggingface.co/lllyasviel/flux1_dev/resolve/main/flux1-dev-fp8.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/pulid "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/text_encoders "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/text_encoders "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/vae "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/text_encoders "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/vae "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/diffusion_models/Wan2.1 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors"

RUN aria2c --console-log-level=error -c -x 8 -s 8 -d /comfyui/models/loras "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

ENV COMFY_MODEL_DIR=/comfyui/models