# Dockerfile for RunPod ComfyUI Worker
# With Network Volume support for large models

FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui

# ============================================================
# 1) CUSTOM NODES
# ============================================================
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes \
 && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
 && git clone --depth 1 https://github.com/arthurtravers/ComfyUI-VideoOutputBridge.git \
 && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git \
 && git clone --depth 1 https://github.com/balazik/ComfyUI-PuLID-Flux.git

RUN pip install --no-cache-dir bitsandbytes insightface onnxruntime-gpu facexlib

RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
      [ -f "$req" ] && pip install --no-cache-dir -r "$req" || true; \
    done

# ============================================================
# 2) CREATE ALL MODEL DIRECTORIES
# ============================================================
RUN mkdir -p /comfyui/models/checkpoints \
             /comfyui/models/diffusion_models/Wan2.1 \
             /comfyui/models/text_encoders \
             /comfyui/models/clip \
             /comfyui/models/vae \
             /comfyui/models/loras \
             /comfyui/models/pulid \
             /comfyui/models/insightface/models/antelopev2 \
             /comfyui/input

# ============================================================
# 3) BAKE SMALL/MEDIUM MODELS INTO IMAGE
# ============================================================

# LoRA - Pixar 3D style (~200MB)
RUN aria2c -x 8 -s 8 -d /comfyui/models/loras \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# PuLID model (~1GB) - CORRECT PATH
RUN aria2c -x 16 -s 16 -d /comfyui/models/pulid \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors"

# InsightFace models for face detection (required by PuLID)
RUN cd /comfyui/models/insightface/models/antelopev2 && \
    aria2c -x 8 "https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx" && \
    aria2c -x 8 "https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx" && \
    aria2c -x 8 "https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx" && \
    aria2c -x 8 "https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx" && \
    aria2c -x 8 "https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx"

# ============================================================
# 4) LARGE MODELS → NETWORK VOLUME
#    Pre-download to volume, then symlink at runtime
# ============================================================

# Create startup script that symlinks Network Volume models
RUN echo '#!/bin/bash\n\
echo "🔍 Setting up models from Network Volume..."\n\
\n\
if [ -d "/runpod-volume/models" ]; then\n\
    echo "✅ Network Volume found at /runpod-volume"\n\
    \n\
    # FLUX FP8 checkpoint\n\
    if [ -f "/runpod-volume/models/checkpoints/flux1-dev-fp8.safetensors" ]; then\n\
        ln -sf /runpod-volume/models/checkpoints/flux1-dev-fp8.safetensors /comfyui/models/checkpoints/\n\
        echo "✅ Linked FLUX FP8 model"\n\
    else\n\
        echo "⚠️ FLUX model not found on volume"\n\
    fi\n\
    \n\
    # Wan 2.1 I2V\n\
    if [ -f "/runpod-volume/models/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors" ]; then\n\
        ln -sf /runpod-volume/models/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors /comfyui/models/diffusion_models/Wan2.1/\n\
        echo "✅ Linked Wan 2.1 I2V model"\n\
    else\n\
        echo "⚠️ Wan 2.1 model not found on volume"\n\
    fi\n\
    \n\
    # VAE (if present)\n\
    if [ -f "/runpod-volume/models/vae/ae.safetensors" ]; then\n\
        ln -sf /runpod-volume/models/vae/ae.safetensors /comfyui/models/vae/\n\
        echo "✅ Linked VAE"\n\
    fi\n\
    \n\
else\n\
    echo "❌ Network Volume NOT mounted at /runpod-volume"\n\
    echo "   Large models will need to download at runtime (may timeout!)"\n\
fi\n\
\n\
echo ""\n\
echo "📁 Model check:"\n\
ls -lh /comfyui/models/checkpoints/*.safetensors 2>/dev/null || echo "   checkpoints: (empty)"\n\
ls -lh /comfyui/models/diffusion_models/Wan2.1/*.safetensors 2>/dev/null || echo "   Wan2.1: (empty)"\n\
ls -lh /comfyui/models/pulid/*.safetensors 2>/dev/null || echo "   pulid: (empty)"\n\
' > /setup_volume.sh && chmod +x /setup_volume.sh

# ============================================================
# 5) DUMMY FILES FOR VALIDATOR
# ============================================================
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ============================================================
# 6) ENVIRONMENT VARIABLES
# ============================================================
ENV COMFY_MODEL_DIR=/comfyui/models
ENV INSIGHTFACE_ROOT=/comfyui/models/insightface

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*