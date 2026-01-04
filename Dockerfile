# Dockerfile for RunPod ComfyUI Worker
# With Network Volume support for large models

FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 wget unzip \
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
             /comfyui/models/diffusion_models \
             /comfyui/models/text_encoders \
             /comfyui/models/clip \
             /comfyui/models/vae \
             /comfyui/models/loras \
             /comfyui/models/pulid \
             /comfyui/models/insightface \
             /comfyui/input

# ============================================================
# 3) BAKE SMALL/MEDIUM MODELS INTO IMAGE
# ============================================================

# LoRA - Pixar 3D style (~200MB)
RUN aria2c -x 8 -s 8 \
    -d /comfyui/models/loras \
    -o Canopus-Pixar-3D-FluxDev-LoRA.safetensors \
    "https://huggingface.co/prithivMLmods/Canopus-Pixar-3D-Flux-LoRA/resolve/main/Canopus-Pixar-3D-FluxDev-LoRA.safetensors"

# PuLID model (~1GB)
RUN aria2c -x 16 -s 16 --file-allocation=none \
    -d /comfyui/models/pulid \
    -o pulid_flux_v0.9.1.safetensors \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors" && \
    ls -la /comfyui/models/pulid/ && \
    test -f /comfyui/models/pulid/pulid_flux_v0.9.1.safetensors && \
    echo "✅ PuLID model verified at /comfyui/models/pulid/"

# ============================================================
# 4) InsightFace antelopev2 models
# ============================================================
RUN echo "Downloading InsightFace antelopev2 models..." && \
    mkdir -p /comfyui/models/insightface/models/antelopev2 && \
    cd /comfyui/models/insightface/models/antelopev2 && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx && \
    echo "✅ InsightFace models downloaded" && \
    ls -la

# ============================================================
# 5) extra_model_paths.yaml - using echo commands
# ============================================================
RUN echo "# ComfyUI Extra Model Paths Configuration" > /comfyui/extra_model_paths.yaml && \
    echo "" >> /comfyui/extra_model_paths.yaml && \
    echo "comfyui:" >> /comfyui/extra_model_paths.yaml && \
    echo "    base_path: /comfyui/models/" >> /comfyui/extra_model_paths.yaml && \
    echo "    checkpoints: checkpoints/" >> /comfyui/extra_model_paths.yaml && \
    echo "    diffusion_models: diffusion_models/" >> /comfyui/extra_model_paths.yaml && \
    echo "    clip: clip/" >> /comfyui/extra_model_paths.yaml && \
    echo "    vae: vae/" >> /comfyui/extra_model_paths.yaml && \
    echo "    loras: loras/" >> /comfyui/extra_model_paths.yaml && \
    echo "    pulid: pulid/" >> /comfyui/extra_model_paths.yaml && \
    echo "    insightface: insightface/" >> /comfyui/extra_model_paths.yaml && \
    echo "" >> /comfyui/extra_model_paths.yaml && \
    echo "runpod_volume:" >> /comfyui/extra_model_paths.yaml && \
    echo "    base_path: /runpod-volume/models/" >> /comfyui/extra_model_paths.yaml && \
    echo "    checkpoints: checkpoints/" >> /comfyui/extra_model_paths.yaml && \
    echo "    diffusion_models: diffusion_models/" >> /comfyui/extra_model_paths.yaml && \
    echo "    clip: clip/" >> /comfyui/extra_model_paths.yaml && \
    echo "    vae: vae/" >> /comfyui/extra_model_paths.yaml && \
    echo "    loras: loras/" >> /comfyui/extra_model_paths.yaml

# ============================================================
# 6) Patch PuLID node - using echo for Python script
# ============================================================
RUN echo 'import re' > /tmp/patch_pulid.py && \
    echo 'path = "/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py"' >> /tmp/patch_pulid.py && \
    echo 'with open(path, "r", encoding="utf-8") as f:' >> /tmp/patch_pulid.py && \
    echo '    content = f.read()' >> /tmp/patch_pulid.py && \
    echo 'content = re.sub(r",\\s*providers=\\[[^\\]]*\\]", "", content)' >> /tmp/patch_pulid.py && \
    echo 'if "INSIGHTFACE_DIR =" in content:' >> /tmp/patch_pulid.py && \
    echo '    content = re.sub(r"INSIGHTFACE_DIR\\s*=\\s*.*", "INSIGHTFACE_DIR = \"/comfyui/models/insightface\"", content)' >> /tmp/patch_pulid.py && \
    echo 'with open(path, "w", encoding="utf-8") as f:' >> /tmp/patch_pulid.py && \
    echo '    f.write(content)' >> /tmp/patch_pulid.py && \
    echo 'print("✅ Patched pulidflux.py")' >> /tmp/patch_pulid.py

RUN python3 /tmp/patch_pulid.py && rm /tmp/patch_pulid.py

# ============================================================
# 7) Register PuLID model folder
# ============================================================
RUN echo '' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '# Register PuLID model path' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'import folder_paths' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'try:' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    folder_paths.add_model_folder_path("pulid", "/comfyui/models/pulid")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    print("✅ PuLID model path registered: /comfyui/models/pulid")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'except Exception as e:' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    print(f"⚠️ PuLID path registration: {e}")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py

# ============================================================
# 8) InsightFace cache directory link
# ============================================================
RUN mkdir -p /root/.insightface && \
    rm -rf /root/.insightface/models && \
    ln -sf /comfyui/models/insightface/models /root/.insightface/models && \
    echo "✅ InsightFace cache directory configured"

# ============================================================
# 9) Volume setup
# ============================================================
COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

# ============================================================
# 10) Dummy files
# ============================================================
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ============================================================
# 11) Env vars
# ============================================================
ENV COMFY_MODEL_DIR=/comfyui/models
ENV INSIGHTFACE_ROOT=/comfyui/models/insightface
ENV INSIGHTFACE_MODELS_ROOT=/comfyui/models/insightface/models
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# 12) Final verification
# ============================================================
RUN echo "=== FINAL BUILD VERIFICATION ===" && \
    echo "1) PuLID model:" && ls -lh /comfyui/models/pulid/ && \
    echo "2) InsightFace models:" && ls -lh /comfyui/models/insightface/models/antelopev2/ && \
    echo "3) Checking patch:" && \
    (grep -q "providers=" /comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py && echo "  ⚠️ providers still present" || echo "  ✅ providers removed") && \
    echo "4) extra_model_paths.yaml:" && cat /comfyui/extra_model_paths.yaml && \
    echo "=== BUILD COMPLETE ==="