FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

# ---- system deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# -------------------------------------------------------------------
# 1) Custom nodes only (fast)
# -------------------------------------------------------------------
RUN mkdir -p /comfyui/custom_nodes \
 && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

# Python deps (keep lean; avoid compiling huge stuff)
RUN pip install --no-cache-dir bitsandbytes insightface onnxruntime-gpu facexlib

# Install requirements from custom nodes (best-effort)
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
      [ -f "$req" ] && pip install --no-cache-dir -r "$req" || true; \
    done

# -------------------------------------------------------------------
# 2) Create model directories
# -------------------------------------------------------------------
RUN mkdir -p \
  /comfyui/models/checkpoints \
  /comfyui/models/text_encoders \
  /comfyui/models/vae \
  /comfyui/models/clip_vision \
  /comfyui/models/diffusion_models/Wan2.1 \
  /comfyui/models/loras \
  /comfyui/models/pulid \
  /comfyui/models/clip \
  /comfyui/models/insightface/models/antelopev2

# -------------------------------------------------------------------
# 3) Add runtime model downloader
# -------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV COMFY_MODEL_DIR=/comfyui/models
ENV MODELS_DIR=/comfyui/models

ENTRYPOINT ["/entrypoint.sh"]