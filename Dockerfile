FROM runpod/worker-comfyui:5.5.0-base

RUN wget -O /comfyui/comfy/ldm/flux/model.py \
    "https://gist.githubusercontent.com/diveddie/d7b977e483f2ec486a3cf4f52bf9b409/raw/model.py"

COPY start.sh /start.sh
RUN chmod +x /start.sh
    
CMD ["/start.sh"]