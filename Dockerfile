# Dockerfile for RunPod ComfyUI Worker
# Lightweight - models loaded from network volume at runtime

FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# Custom nodes only (small)
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
    && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    && git clone https://github.com/XLabs-AI/x-flux-comfyui.git \
    && pip install --no-cache-dir -r x-flux-comfyui/requirements.txt

# Create model directories
RUN mkdir -p /comfyui/models/checkpoints \
             /comfyui/models/diffusion_models \
             /comfyui/models/text_encoders \
             /comfyui/models/clip \
             /comfyui/models/vae \
             /comfyui/models/loras \
             /comfyui/models/ipadapter \
             /comfyui/models/clip_vision \
             /comfyui/input

# Copy setup script
COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

# Extra model paths config
RUN printf '%s\n' \
"comfyui:" \
"  base_path: /comfyui/models/" \
"  checkpoints: checkpoints/" \
"  diffusion_models: diffusion_models/" \
"  clip: clip/" \
"  vae: vae/" \
"  loras: loras/" \
"  ipadapter: ipadapter/" \
"  clip_vision: clip_vision/" \
"" \
"runpod_volume:" \
"  base_path: /runpod-volume/models/" \
"  checkpoints: checkpoints/" \
"  diffusion_models: diffusion_models/" \
"  clip: clip/" \
"  vae: vae/" \
"  loras: loras/" \
"  clip_vision: clip_vision/" \
> /comfyui/extra_model_paths.yaml

# Dummy inputs
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

ENV COMFY_MODEL_DIR=/comfyui/models
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# No big model downloads - keep image small!