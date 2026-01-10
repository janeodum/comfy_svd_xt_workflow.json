FROM runpod/worker-comfyui:5.5.1-base

# install custom nodes into comfyui (first node with --mode remote to fetch updated cache)
RUN comfy node install --exit-on-fail x-flux-comfyui --mode remote
RUN wget -O /comfyui/comfy/ldm/flux/model.py \
    "https://gist.githubusercontent.com/diveddie/d7b977e483f2ec486a3cf4f52bf9b409/raw/model.py"

# download models into comfyui
RUN comfy model download --url https://huggingface.co/XLabs-AI/flux-ip-adapter/resolve/main/ip_adapter.safetensors --relative-path models/xlabs/ipadapters --filename ip_adapter.safetensors
RUN comfy model download --url https://huggingface.co/XLabs-AI/flux-ip-adapter/blob/d3cb0c5bb46ff37bf3deb241f02987dfcf9a7963/clip_vision_l.safetensors --relative-path models/clip_vision --filename clip_vision_l.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors --relative-path models/checkpoints/FLUX1 --filename flux1-dev-fp8.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors --relative-path models/text_encoders --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors --relative-path models/vae --filename wan_2.1_vae.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors --relative-path models/diffusion_models/Wan2.1 --filename wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors --relative-path models/clip_vision --filename clip_vision_h.safetensors

RUN wget --no-verbose -O /comfyui/models/loras/Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"
# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/

COPY start.sh /start.sh
RUN chmod +x /start.sh
    
CMD ["/start.sh"]