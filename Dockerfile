# OMNIA WORKER - UPDATED WITH GIST model.py
FROM runpod/worker-comfyui:5.5.1-base

# 1. Install Custom Nodes properly using comfy-cli
RUN comfy node install ComfyUI-VideoHelperSuite \
    && comfy node install ComfyUI-VideoOutputBridge \
    && comfy node install x-flux-comfyui

# 2. OVERWRITE model.py with your specific Gist code
# We target the exact directory: /comfyui/comfy/ldm/flux/
RUN wget -O /comfyui/comfy/ldm/flux/model.py \
    "https://gist.githubusercontent.com/diveddie/d7b977e483f2ec486a3cf4f52bf9b409/raw/model.py"

# 3. Download Models (Grouped for easier debugging)
# CLIP & IP-Adapter Models
RUN comfy model download --url https://huggingface.co/XLabs-AI/flux-ip-adapter/resolve/main/ip_adapter.safetensors --relative-path models/xlabs/ipadapters --filename ip_adapter.safetensors
RUN comfy model download --url https://huggingface.co/XLabs-AI/flux-ip-adapter/resolve/main/clip_vision_l.safetensors --relative-path models/clip_vision --filename clip_vision_l.safetensors

# Wan 2.1 specific models
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors --relative-path models/text_encoders --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors --relative-path models/vae --filename wan_2.1_vae.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors --relative-path models/clip_vision --filename clip_vision_h.safetensors

# LoRA - Pixar 3D style
RUN wget --no-verbose -O /comfyui/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# 4. CRITICAL: Handle the 14B Model (Avoid timeout)
# If this build fails, remove the line below and use the AWS CLI method for the 14B file.
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors --relative-path models/diffusion_models/Wan2.1 --filename wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors

# 5. Environment & Input Setup
COPY input/ /comfyui/input/

RUN echo "Omnnia Worker Build with Gist Patch Complete"