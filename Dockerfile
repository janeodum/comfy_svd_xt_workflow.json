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
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/det_10g.onnx -O det_10g.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/2d106det.onnx -O 2d106det.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/genderage.onnx -O genderage.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/1k3d68.onnx -O 1k3d68.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/glintr100.onnx -O glintr100.onnx || true && \
    ( [ ! -f det_10g.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx -O det_10g.onnx || true ) && \
    ( [ ! -f 2d106det.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx -O 2d106det.onnx || true ) && \
    ( [ ! -f genderage.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx -O genderage.onnx || true ) && \
    ( [ ! -f 1k3d68.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx -O 1k3d68.onnx || true ) && \
    ( [ ! -f glintr100.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx -O glintr100.onnx || true ) && \
    echo "✅ InsightFace models downloaded" && \
    ls -la

# ============================================================
# 5) extra_model_paths.yaml (NO heredoc)
# ============================================================
RUN printf '%s\n' \
"# ComfyUI Extra Model Paths Configuration" \
"# This file tells ComfyUI where to find models" \
"" \
"comfyui:" \
"  base_path: /comfyui/models/" \
"  checkpoints: checkpoints/" \
"  diffusion_models: diffusion_models/" \
"  clip: clip/" \
"  vae: vae/" \
"  loras: loras/" \
"  pulid: pulid/" \
"  insightface: insightface/" \
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
# 6) Patch PuLID node (NO multiline python)
# ============================================================

# Patch 1: remove providers=[...] anywhere
RUN python3 -c 'import re; p="/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py"; s=open(p,"r",encoding="utf-8").read(); s=re.sub(r",\s*providers=\[.*?\]","",s,flags=re.S); open(p,"w",encoding="utf-8").write(s); print("✅ Removed providers=[...]")'

# Patch 2: force INSIGHTFACE_DIR to absolute path (replace line if exists, otherwise append)
RUN python3 -c 'import re; p="/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py"; s=open(p,"r",encoding="utf-8").read(); \
s = re.sub(r"^INSIGHTFACE_DIR\s*=.*$", "INSIGHTFACE_DIR = \"/comfyui/models/insightface\"", s, flags=re.M) if re.search(r"^INSIGHTFACE_DIR\s*=", s, flags=re.M) else "INSIGHTFACE_DIR = \"/comfyui/models/insightface\"\n" + s; \
open(p,"w",encoding="utf-8").write(s); print("✅ Set INSIGHTFACE_DIR to /comfyui/models/insightface")'
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
# 9) Test script (NO heredoc)
# ============================================================
RUN printf '%s\n' \
"#!/usr/bin/env python3" \
"import os, sys" \
"print('=== Testing InsightFace Fix ===')" \
"os.environ['INSIGHTFACE_ROOT'] = '/comfyui/models/insightface'" \
"os.environ['INSIGHTFACE_MODELS_ROOT'] = '/comfyui/models/insightface/models'" \
"model_path = '/comfyui/models/insightface/models/antelopev2'" \
"if not os.path.exists(model_path):" \
"    print(f'❌ Model directory not found: {model_path}'); sys.exit(1)" \
"files = os.listdir(model_path)" \
"print(f'Models found: {files}')" \
"required = ['det_10g.onnx','2d106det.onnx','genderage.onnx','1k3d68.onnx','glintr100.onnx']" \
"alts = {'scrfd_10g_bnkps.onnx':'det_10g.onnx'}" \
"for r in required:" \
"    ok = (r in files) or any((a in files and alts[a]==r) for a in alts)" \
"    print(('✅ Found ' + r) if ok else ('⚠️ Missing: ' + r))" \
"print('✅ Test complete')" \
> /test_insightface_fix.py && chmod +x /test_insightface_fix.py

# ============================================================
# 10) Volume setup
# ============================================================
COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

# ============================================================
# 11) Dummy files
# ============================================================
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ============================================================
# 12) Env vars
# ============================================================
ENV COMFY_MODEL_DIR=/comfyui/models
ENV INSIGHTFACE_ROOT=/comfyui/models/insightface
ENV INSIGHTFACE_MODELS_ROOT=/comfyui/models/insightface/models
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# 13) Final verification (NO multiline python)
# ============================================================
RUN echo "=== FINAL BUILD VERIFICATION ===" && \
    echo "" && \
    echo "1) PuLID model:" && ls -lh /comfyui/models/pulid/ && \
    echo "" && \
    echo "2) InsightFace models:" && ls -lh /comfyui/models/insightface/models/antelopev2/ && \
    echo "" && \
    echo "3) Running test:" && python3 /test_insightface_fix.py && \
    echo "" && \
    echo "4) Patch check:" && \
    python3 -c 's=open("/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py","r").read(); print("INSIGHTFACE_DIR ok" if "INSIGHTFACE_DIR = \\"/comfyui/models/insightface\\"" in s else "INSIGHTFACE_DIR missing"); print("providers removed" if "providers=[" not in s else "providers STILL present")' && \
    echo "" && \
    echo "5) extra_model_paths.yaml:" && cat /comfyui/extra_model_paths.yaml && \
    echo "" && \
    echo "=== BUILD COMPLETE ==="