FROM runpod/worker-comfyui:5.5.1-base

# install custom nodes into comfyui (first node with --mode remote to fetch updated cache)
# Could not resolve unknown_registry node VHS_VideoCombine — no aux_id provided; skipped
# Could not resolve unknown_registry node WanImageToVideo — no aux_id provided; skipped
# Could not resolve unknown_registry node CLIPVisionEncode — no aux_id provided; skipped
# Could not resolve unknown_registry node CLIPVisionLoader — no aux_id provided; skipped

# download models into comfyui
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors --relative-path models/text_encoders --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors --relative-path models/vae --filename wan_2.1_vae.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors --relative-path models/diffusion_models/Wan2.1 --filename wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors --relative-path models/clip_vision --filename clip_vision_h.safetensors

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/



# # Dockerfile for RunPod ComfyUI Worker
# # Lightweight - models loaded from network volume at runtime

# FROM runpod/worker-comfyui:5.5.0-base

# SHELL ["/bin/bash", "-lc"]

# RUN apt-get update && apt-get install -y --no-install-recommends \
#     git ffmpeg curl ca-certificates wget \
#     && rm -rf /var/lib/apt/lists/*

# WORKDIR /comfyui

# # Custom nodes only (small)
# RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
#     && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
#     && git clone https://github.com/XLabs-AI/x-flux-comfyui.git \
#     && pip install --no-cache-dir -r x-flux-comfyui/requirements.txt

# # Create model directories
# RUN mkdir -p /comfyui/models/checkpoints \
#              /comfyui/models/diffusion_models \
#              /comfyui/models/text_encoders \
#              /comfyui/models/clip \
#              /comfyui/models/vae \
#              /comfyui/models/loras \
#              /comfyui/models/ipadapter \
#              /comfyui/models/clip_vision \
#              /comfyui/input

# # Copy setup script
# COPY setup_volume.sh /setup_volume.sh
# RUN chmod +x /setup_volume.sh

# # Extra model paths config
# RUN printf '%s\n' \
# "comfyui:" \
# "  base_path: /comfyui/models/" \
# "  checkpoints: checkpoints/" \
# "  diffusion_models: diffusion_models/" \
# "  clip: clip/" \
# "  vae: vae/" \
# "  loras: loras/" \
# "  ipadapter: ipadapter/" \
# "  clip_vision: clip_vision/" \
# "" \
# "runpod_volume:" \
# "  base_path: /runpod-volume/models/" \
# "  checkpoints: checkpoints/" \
# "  diffusion_models: diffusion_models/" \
# "  clip: clip/" \
# "  vae: vae/" \
# "  loras: loras/" \
# "  clip_vision: clip_vision/" \
# > /comfyui/extra_model_paths.yaml

# # Dummy inputs
# RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ENV COMFY_MODEL_DIR=/comfyui/models
# ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# # Cleanup
# RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# # No big model downloads - keep image small!