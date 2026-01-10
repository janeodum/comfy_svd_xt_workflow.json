FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# # Custom nodes only (small)
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
    && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    && git clone https://github.com/XLabs-AI/x-flux-comfyui.git \
    && pip install --no-cache-dir -r x-flux-comfyui/requirements.txt
