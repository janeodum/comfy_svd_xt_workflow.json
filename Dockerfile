# OMNIA WORKER - LIGHTWEIGHT (Models from Network Volume)
FROM runpod/worker-comfyui:5.5.1-base

# 2. OVERWRITE model.py with your Gist patch
RUN wget -O /comfyui/comfy/ldm/flux/model.py \
    "https://gist.githubusercontent.com/diveddie/d7b977e483f2ec486a3cf4f52bf9b409/raw/model.py"

# 3. Create model directories (empty - will be symlinked)
RUN mkdir -p /comfyui/models/checkpoints \
             /comfyui/models/diffusion_models \
             /comfyui/models/text_encoders \
             /comfyui/models/clip_vision \
             /comfyui/models/vae \
             /comfyui/models/loras \
             /comfyui/models/xlabs/ipadapters

# 4. Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 5. NO MODEL DOWNLOADS - Keep image small!

RUN echo "Omnnia Worker Lightweight Build Complete"

CMD ["/start.sh"]