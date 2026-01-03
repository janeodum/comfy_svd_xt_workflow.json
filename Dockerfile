FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# 1) Custom nodes
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

RUN pip install --no-cache-dir bitsandbytes insightface onnxruntime-gpu facexlib
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
      [ -f "$req" ] && pip install --no-cache-dir -r "$req" || true; \
    done

# 2) Bake ONLY small/medium models into the image
RUN mkdir -p /comfyui/models/text_encoders /comfyui/models/vae /comfyui/models/loras
RUN aria2c -x 8 -s 8 -d /comfyui/models/loras "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"
RUN aria2c -x 8 -s 8 -d /comfyui/models/vae "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
RUN aria2c -x 16 -s 16 -d pulid "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors"
# Add other small encoders here...

# 3) Setup for Network Volume
# We create the folders where the Volume will be mounted
RUN mkdir -p /comfyui/models/checkpoints /comfyui/models/diffusion_models/Wan2.1 /comfyui/models/pulid

# 4) Dummy files for validator
RUN mkdir -p /comfyui/input && touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

ENV COMFY_MODEL_DIR=/comfyui/models