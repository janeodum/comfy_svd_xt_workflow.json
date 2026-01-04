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

RUN pip install --no-cache-dir bitsandbytes facexlib

# Install requirements from custom nodes
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
      [ -f "$req" ] && pip install --no-cache-dir -r "$req" || true; \
    done

# Install insightface and onnxruntime (latest versions)
RUN pip install --no-cache-dir insightface onnxruntime-gpu

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
RUN aria2c -x 8 -s 8 \
    -d /comfyui/models/loras \
    -o Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# PuLID model (~1GB) - CACHE_BUST_V3 - explicit filename
RUN aria2c -x 16 -s 16 --file-allocation=none \
    -d /comfyui/models/pulid \
    -o pulid_flux_v0.9.1.safetensors \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors" && \
    ls -la /comfyui/models/pulid/ && \
    test -f /comfyui/models/pulid/pulid_flux_v0.9.1.safetensors && \
    echo "✅ PuLID model verified at /comfyui/models/pulid/"

# Add extra model paths config (includes pulid folder)
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# ============================================================
# KEY FIX: Register PuLID folder path with ComfyUI directly
# This ensures the PuLID node can find models at startup
# ============================================================
RUN echo 'import folder_paths' > /comfyui/custom_nodes/ComfyUI-PuLID-Flux/register_pulid.py && \
    echo 'folder_paths.add_model_folder_path("pulid", "/comfyui/models/pulid")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/register_pulid.py && \
    echo 'print("✅ PuLID model path registered: /comfyui/models/pulid")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/register_pulid.py

# Also ensure __init__.py imports our registration (append to existing)
RUN echo '' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '# Register PuLID model path' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'try:' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    import folder_paths' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    folder_paths.add_model_folder_path("pulid", "/comfyui/models/pulid")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'except Exception as e:' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    print(f"PuLID path registration: {e}")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py

# ============================================================
# FIX: Patch InsightFace API compatibility in PuLID
# Newer InsightFace versions don't accept 'providers' in __init__
# We remove the providers argument - InsightFace will use default
# ============================================================
RUN python3 -c "\
import re; \
path = '/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py'; \
with open(path, 'r') as f: content = f.read(); \
patched = re.sub(r',\s*providers=\[[^\]]*\]', '', content); \
with open(path, 'w') as f: f.write(patched); \
print('✅ Patched InsightFace providers argument'); \
"

# InsightFace models for face detection (required by PuLID)
RUN cd /comfyui/models/insightface/models/antelopev2 && \
    aria2c -x 8 -o 1k3d68.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx" && \
    aria2c -x 8 -o 2d106det.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx" && \
    aria2c -x 8 -o genderage.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx" && \
    aria2c -x 8 -o glintr100.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx" && \
    aria2c -x 8 -o scrfd_10g_bnkps.onnx "https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx" && \
    ls -la

# ============================================================
# 4) LARGE MODELS → NETWORK VOLUME
#    Pre-download to volume, then symlink at runtime
# ============================================================

# Create startup script that symlinks Network Volume models
COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

# ============================================================
# 5) DUMMY FILES FOR VALIDATOR
# ============================================================
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ============================================================
# 6) ENVIRONMENT VARIABLES
# ============================================================
ENV COMFY_MODEL_DIR=/comfyui/models
ENV INSIGHTFACE_ROOT=/comfyui/models/insightface
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# 7) BUILD VERIFICATION
# ============================================================
RUN echo "=== FINAL BUILD VERIFICATION ===" && \
    echo "PuLID model:" && (ls -lh /comfyui/models/pulid/ || echo "  (empty)") && \
    echo "InsightFace models:" && (ls /comfyui/models/insightface/models/antelopev2/ || echo "  (empty)") && \
    echo "Registration script:" && cat /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py | tail -10 && \
    echo "InsightFace patch check:" && (grep -q "providers=" /comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py && echo "  ⚠️ providers still present" || echo "  ✅ providers removed") && \
    echo "=== BUILD COMPLETE ==="