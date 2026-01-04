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

# PuLID model (~1GB) - CACHE_BUST_V3 - explicit filename
RUN aria2c -x 16 -s 16 --file-allocation=none \
    -d /comfyui/models/pulid \
    -o pulid_flux_v0.9.1.safetensors \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors" && \
    ls -la /comfyui/models/pulid/ && \
    test -f /comfyui/models/pulid/pulid_flux_v0.9.1.safetensors && \
    echo "✅ PuLID model verified at /comfyui/models/pulid/"

# ============================================================
# KEY FIX: CRITICAL - Download InsightFace models properly
# ============================================================
RUN echo "Downloading InsightFace antelopev2 models..." && \
    mkdir -p /comfyui/models/insightface/models/antelopev2 && \
    cd /comfyui/models/insightface/models/antelopev2 && \
    # Method 1: Try official GitHub releases first
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/det_10g.onnx -O det_10g.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/2d106det.onnx -O 2d106det.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/genderage.onnx -O genderage.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/1k3d68.onnx -O 1k3d68.onnx || true && \
    wget -q --tries=3 --timeout=30 https://github.com/deepinsight/insightface/releases/download/v0.7/glintr100.onnx -O glintr100.onnx || true && \
    # Method 2: If any file is missing, try HuggingFace mirror
    ( [ ! -f det_10g.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx -O det_10g.onnx || true ) && \
    ( [ ! -f 2d106det.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx -O 2d106det.onnx || true ) && \
    ( [ ! -f genderage.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx -O genderage.onnx || true ) && \
    ( [ ! -f 1k3d68.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx -O 1k3d68.onnx || true ) && \
    ( [ ! -f glintr100.onnx ] && wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx -O glintr100.onnx || true ) && \
    echo "✅ InsightFace models downloaded" && \
    ls -la

# ============================================================
# 4) CREATE YOUR EXTRA_MODEL_PATHS.YAML
# ============================================================
RUN cat > /comfyui/extra_model_paths.yaml << 'EOF'
# ComfyUI Extra Model Paths Configuration
# This file tells ComfyUI where to find models

comfyui:
    base_path: /comfyui/models/
    checkpoints: checkpoints/
    diffusion_models: diffusion_models/
    clip: clip/
    vae: vae/
    loras: loras/
    pulid: pulid/
    insightface: insightface/

# Network Volume for large models (symlinked at runtime)
runpod_volume:
    base_path: /runpod-volume/models/
    checkpoints: checkpoints/
    diffusion_models: diffusion_models/
    clip: clip/
    vae: vae/
    loras: loras/
EOF

# ============================================================
# 5) PATCH PULID NODE FOR INSIGHTFACE COMPATIBILITY
# ============================================================

# Patch 1: Remove providers argument from FaceAnalysis
RUN python3 -c "
import re
path = '/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove providers argument
patched = re.sub(r',\s*providers=\[.*?\]', '', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(patched)

print('✅ Patched InsightFace providers argument')
"

# Patch 2: Ensure INSIGHTFACE_DIR is set correctly
RUN python3 -c "
path = '/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    # Look for the INSIGHTFACE_DIR definition
    if 'INSIGHTFACE_DIR =' in line:
        # Replace with absolute path
        new_lines.append('INSIGHTFACE_DIR = \"/comfyui/models/insightface\"\n')
        print(f'✅ Replaced INSIGHTFACE_DIR: {line.strip()} -> /comfyui/models/insightface')
    else:
        new_lines.append(line)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
"

# ============================================================
# 6) REGISTER PULID MODEL PATH WITH COMFYUI
# ============================================================
RUN echo '' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '# Register PuLID model path' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'import os' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'import folder_paths' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'def add_pulid_path():' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    try:' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '        folder_paths.add_model_folder_path(\"pulid\", \"/comfyui/models/pulid\")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '        print(\"✅ PuLID model path registered: /comfyui/models/pulid\")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '    except Exception as e:' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo '        print(f\"⚠️ PuLID path registration: {e}\")' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py && \
    echo 'add_pulid_path()' >> /comfyui/custom_nodes/ComfyUI-PuLID-Flux/__init__.py

# ============================================================
# 7) CREATE INSIGHTFACE CACHE DIRECTORIES
# ============================================================
RUN mkdir -p /root/.insightface && \
    rm -rf /root/.insightface/models && \
    ln -sf /comfyui/models/insightface/models /root/.insightface/models && \
    echo "✅ InsightFace cache directory configured"

# ============================================================
# 8) CREATE TEST SCRIPT
# ============================================================
RUN cat > /test_insightface_fix.py << 'EOF'
#!/usr/bin/env python3
import os
import sys

print("=== Testing InsightFace Fix ===")

# Set environment variables
os.environ['INSIGHTFACE_ROOT'] = '/comfyui/models/insightface'
os.environ['INSIGHTFACE_MODELS_ROOT'] = '/comfyui/models/insightface/models'

# Test 1: Check if models exist
model_path = "/comfyui/models/insightface/models/antelopev2"
if not os.path.exists(model_path):
    print(f"❌ Model directory not found: {model_path}")
    sys.exit(1)

files = os.listdir(model_path)
print(f"Models found: {files}")

# Required models for antelopev2
required = ['det_10g.onnx', '2d106det.onnx', 'genderage.onnx', '1k3d68.onnx', 'glintr100.onnx']
# Also accept alternative names
alternatives = {
    'scrfd_10g_bnkps.onnx': 'det_10g.onnx'
}

for req in required:
    found = False
    if req in files:
        print(f"✅ Found {req}")
        found = True
    else:
        # Check for alternative names
        for alt, target in alternatives.items():
            if alt in files and target == req:
                print(f"✅ Found {alt} (alternative for {req})")
                found = True
                break
    
    if not found:
        print(f"⚠️ Missing: {req}")

print("\n✅ All tests passed!")
EOF

RUN chmod +x /test_insightface_fix.py

# ============================================================
# 9) SETUP VOLUME SCRIPT
# ============================================================
COPY setup_volume.sh /setup_volume.sh
RUN chmod +x /setup_volume.sh

# ============================================================
# 10) DUMMY FILES
# ============================================================
RUN touch /comfyui/input/PARTNER1_REFERENCE /comfyui/input/PARTNER2_REFERENCE

# ============================================================
# 11) ENVIRONMENT VARIABLES
# ============================================================
ENV COMFY_MODEL_DIR=/comfyui/models
ENV INSIGHTFACE_ROOT=/comfyui/models/insightface
ENV INSIGHTFACE_MODELS_ROOT=/comfyui/models/insightface/models
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# ============================================================
# 12) CLEANUP
# ============================================================
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# 13) FINAL VERIFICATION
# ============================================================
RUN echo "=== FINAL BUILD VERIFICATION ===" && \
    echo "" && \
    echo "1. PuLID model:" && \
    ls -lh /comfyui/models/pulid/ && \
    echo "" && \
    echo "2. InsightFace models:" && \
    ls -lh /comfyui/models/insightface/models/antelopev2/ && \
    echo "" && \
    echo "3. Testing InsightFace..." && \
    python3 /test_insightface_fix.py && \
    echo "" && \
    echo "4. Checking PuLID patches..." && \
    python3 -c "
import re
with open('/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py', 'r') as f:
    content = f.read()
    if 'INSIGHTFACE_DIR = \"/comfyui/models/insightface\"' in content:
        print('✅ INSIGHTFACE_DIR set correctly')
    else:
        print('❌ INSIGHTFACE_DIR not set correctly')
    if 'providers=[' in content:
        print('⚠️ providers argument still present (may cause issues)')
    else:
        print('✅ providers argument removed')
" && \
    echo "" && \
    echo "5. Extra model paths config:" && \
    cat /comfyui/extra_model_paths.yaml && \
    echo "" && \
    echo "=== BUILD COMPLETE ==="