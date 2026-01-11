FROM runpod/worker-comfyui:5.5.1-base
ARG CACHE_BUST=3

RUN apt-get update && apt-get install -y ffmpeg

# Install Custom Nodes WITH their requirements
RUN cd /comfyui/custom_nodes \
    && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    && git clone https://github.com/XLabs-AI/x-flux-comfyui.git \
    && git clone https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
    && pip install -r ComfyUI-VideoHelperSuite/requirements.txt \
    && pip install -r x-flux-comfyui/requirements.txt

# Apply the Flux/Wan model.py Patch
RUN wget -O /comfyui/comfy/ldm/flux/model.py \
    "https://gist.githubusercontent.com/diveddie/d7b977e483f2ec486a3cf4f52bf9b409/raw/model.py"

# Create extra_model_paths.yaml
RUN echo "runpod_volume:" > /comfyui/extra_model_paths.yaml \
    && echo "    base_path: /runpod-volume/models" >> /comfyui/extra_model_paths.yaml \
    && echo "    checkpoints: checkpoints" >> /comfyui/extra_model_paths.yaml \
    && echo "    clip: clip" >> /comfyui/extra_model_paths.yaml \
    && echo "    clip_vision: clip_vision" >> /comfyui/extra_model_paths.yaml \
    && echo "    configs: configs" >> /comfyui/extra_model_paths.yaml \
    && echo "    controlnet: controlnet" >> /comfyui/extra_model_paths.yaml \
    && echo "    diffusion_models: diffusion_models" >> /comfyui/extra_model_paths.yaml \
    && echo "    embeddings: embeddings" >> /comfyui/extra_model_paths.yaml \
    && echo "    loras: loras" >> /comfyui/extra_model_paths.yaml \
    && echo "    upscale_models: upscale_models" >> /comfyui/extra_model_paths.yaml \
    && echo "    vae: vae" >> /comfyui/extra_model_paths.yaml

ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml