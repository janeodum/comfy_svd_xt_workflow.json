FROM runpod/worker-comfyui:5.5.1-base
ARG CACHE_BUST=3

# 1. System dependencies
RUN apt-get update && apt-get install -y ffmpeg

# 2. Install Custom Nodes (Switching to Git Clone for reliability)
RUN mkdir -p /comfyui/custom_nodes \
    && cd /comfyui/custom_nodes \
    && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    && git clone https://github.com/XLabs-AI/x-flux-comfyui.git \
    && git clone https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git

# 3. Apply the Flux/Wan model.py Patch
RUN wget -O /comfyui/comfy/ldm/flux/model.py \
    "https://gist.githubusercontent.com/diveddie/d7b977e483f2ec486a3cf4f52bf9b409/raw/model.py"

# 4. Create the extra_model_paths.yaml File
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

# 5. Download SMALL Support Mode
RUN comfy model download --url https://huggingface.co/XLabs-AI/flux-ip-adapter/resolve/main/ip_adapter.safetensors --relative-path models/xlabs/ipadapters --filename ip_adapter.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors --relative-path models/clip --filename clip_vision_l.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors --relative-path models/text_encoders --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors --relative-path models/vae --filename wan_2.1_vae.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors --relative-path models/clip_vision --filename clip_vision_h.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors --relative-path models/checkpoints/FLUX1 --filename flux1-dev-fp8.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors --relative-path models/diffusion_models/Wan2.1 --filename wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors

# 6. LoRA
RUN wget --no-verbose -O /comfyui/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# 7. Start Command
CMD ["/bin/bash", "-c", "ln -sf /runpod-volume/custom_nodes/* /comfyui/custom_nodes/ 2>/dev/null || true && python -u /comfyui/main.py --listen --port 8188"]
