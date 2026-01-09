FROM runpod/worker-comfyui:5.5.0-base

ENV CACHE_BUSTER=3
SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone --depth 1 https://github.com/XLabs-AI/x-flux-comfyui.git \
 && pip install --no-cache-dir bitsandbytes opencv-python-headless \
 && pip install --no-cache-dir -r x-flux-comfyui/requirements.txt

RUN python3 - <<'PY'
import os
path = "/comfyui/comfy/ldm/flux/layers.py"
if os.path.exists(path):
    with open(path, "r") as f:
        data = f.read()
    data = data.replace("def forward(self, img: Tensor, txt: Tensor, vec: Tensor, pe: Tensor):", 
                        "def forward(self, img: Tensor, txt: Tensor, vec: Tensor, pe: Tensor, **kwargs):")
    data = data.replace("def forward(self, x: Tensor, vec: Tensor, pe: Tensor) -> Tensor:", 
                        "def forward(self, x: Tensor, vec: Tensor, pe: Tensor, **kwargs) -> Tensor:")
    with open(path, "w") as f:
        f.write(data)
PY

RUN mkdir -p /comfyui/models/checkpoints \
             /comfyui/models/diffusion_models \
             /comfyui/models/text_encoders \
             /comfyui/models/clip \
             /comfyui/models/vae \
             /comfyui/models/loras \
             /comfyui/models/ipadapter \
             /comfyui/models/clip_vision \
             /comfyui/input

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
"  ipadapter: ipadapter/" \
"  clip_vision: clip_vision/" \
> /comfyui/extra_model_paths.yaml

COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

ENV COMFY_MODEL_DIR=/comfyui/models
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN echo "BUILD_COMPLETE"