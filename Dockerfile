# Dockerfile for RunPod ComfyUI Worker
# FLUX + XLabs IP-Adapter (LoadFluxIPAdapter / ApplyFluxIPAdapter)

FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# ============================================================
# 1) CUSTOM NODES (must include XLabs FLUX IPAdapter nodes)
# ============================================================
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
 && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone https://github.com/XLabs-AI/x-flux-comfyui.git \
 && pip install --no-cache-dir bitsandbytes opencv-python-headless \
 && pip install --no-cache-dir -r x-flux-comfyui/requirements.txt

# ============================================================
# FIX: Flux attn_mask kwarg mismatch
# DoubleStreamBlock.forward() and SingleStreamBlock.forward() don't accept attn_mask
# Add **kwargs to accept and discard extra arguments
# ============================================================
# RUN python3 - <<'PY'
# from pathlib import Path

# p = Path("/comfyui/comfy/ldm/flux/model.py")
# s = p.read_text(encoding="utf-8")
# original = s

# # Fix DoubleStreamBlock.forward() - add **kwargs before the return type hint
# s = s.replace(
#     "def forward(self, img: Tensor, txt: Tensor, vec: Tensor, pe: Tensor) -> tuple[Tensor, Tensor]:",
#     "def forward(self, img: Tensor, txt: Tensor, vec: Tensor, pe: Tensor, **kwargs) -> tuple[Tensor, Tensor]:"
# )

# # Fix SingleStreamBlock.forward() - add **kwargs before the return type hint
# s = s.replace(
#     "def forward(self, x: Tensor, vec: Tensor, pe: Tensor) -> Tensor:",
#     "def forward(self, x: Tensor, vec: Tensor, pe: Tensor, **kwargs) -> Tensor:"
# )

# if s == original:
#     print("⚠️ Warning: No changes made - signatures may differ or already patched")
#     # Print the file to help debug
#     print("Looking for forward methods in model.py...")
#     for i, line in enumerate(original.split('\n')):
#         if 'def forward' in line:
#             print(f"  Line {i+1}: {line.strip()}")
# else:
#     p.write_text(s, encoding="utf-8")
#     print("✅ Patched FLUX: added **kwargs to forward methods")
# PY

# ============================================================
# 2) MODEL DIRECTORIES (match workflow file names)
# ============================================================
RUN mkdir -p /comfyui/models/checkpoints \
             /comfyui/models/diffusion_models \
             /comfyui/models/text_encoders \
             /comfyui/models/clip \
             /comfyui/models/vae \
             /comfyui/models/loras \
             /comfyui/models/ipadapter \
             /comfyui/models/clip_vision \
             /comfyui/input

# (Optional but helpful) also provide xlabs-style folders in case the node looks there
RUN mkdir -p /comfyui/models/xlabs && \
    ln -sf /comfyui/models/ipadapter    /comfyui/models/xlabs/ipadapters && \
    ln -sf /comfyui/models/clip_vision  /comfyui/models/xlabs/clip_vision


RUN wget --no-verbose \
    -O /comfyui/models/clip_vision/clip_vision_h.safetensors \
    "https://hf-mirror.com/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"


# LoRA - Pixar 3D style (required by workflow
RUN wget --no-verbose \
    -O /comfyui/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# ============================================================
# 4) EXTRA MODEL PATHS YAML (NO HEREDOC)
# ============================================================
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
> /comfyui/extra_model_paths.yaml

# ============================================================
# 5) VOLUME SETUP SCRIPT
# ============================================================
COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

# ============================================================
# 6) DUMMY INPUTS FOR YOUR WORKFLOW
# ============================================================
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ============================================================
# 7) ENVIRONMENT VARIABLES
# ============================================================
ENV COMFY_MODEL_DIR=/comfyui/models
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# 8) FINAL VERIFICATION (paths that actually exist)
# ============================================================
RUN echo "=== FINAL VERIFICATION ===" && \
    echo "IP-Adapter model:" && ls -lh /comfyui/models/ipadapter/ && \
    echo "" && echo "CLIP vision:" && ls -lh /comfyui/models/clip_vision/ && \
    echo "" && echo "XLabs node repo present:" && ls -la /comfyui/custom_nodes/x-flux-comfyui || true && \
    echo "" && echo "extra_model_paths.yaml:" && cat /comfyui/extra_model_paths.yaml && \
    echo "" && echo "=== BUILD COMPLETE ==="