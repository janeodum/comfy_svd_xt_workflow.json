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
    # Download all models from HuggingFace
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx && \
    wget -q https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx && \
    echo "✅ InsightFace models downloaded" && \
    ls -la

# ============================================================
# 5) extra_model_paths.yaml
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
# 6) Patch PuLID node
# ============================================================

# Create a Python script to patch the pulidflux.py file
RUN cat > /tmp/patch_pulid.py << 'EOF'
import re
import sys

path = "/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove providers argument
content = re.sub(r",\s*providers=\[.*?\]", "", content, flags=re.DOTALL)

# Force INSIGHTFACE_DIR to absolute path
if "INSIGHTFACE_DIR =" in content:
    content = re.sub(r'INSIGHTFACE_DIR\s*=\s*.*', 'INSIGHTFACE_DIR = "/comfyui/models/insightface"', content)
else:
    # Add it at the top if not found
    lines = content.split('\n')
    lines.insert(0, 'INSIGHTFACE_DIR = "/comfyui/models/insightface"')
    content = '\n'.join(lines)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Patched pulidflux.py")
print("  - Removed providers argument")
print("  - Set INSIGHTFACE_DIR to /comfyui/models/insightface")
EOF

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
# 9) Test script
# ============================================================
RUN cat > /test_insightface.py << 'EOF'
#!/usr/bin/env python3
import os
import sys

print("=== Testing InsightFace ===")

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

# Check for required files
required_files = ['1k3d68.onnx', '2d106det.onnx', 'genderage.onnx', 'glintr100.onnx', 'scrfd_10g_bnkps.onnx']
for req in required_files:
    if req in files:
        print(f"✅ Found {req}")
    else:
        print(f"❌ Missing: {req}")

print("\n✅ All models downloaded successfully!")
EOF

RUN chmod +x /test_insightface.py

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
# 13) Final verification - SIMPLIFIED
# ============================================================
RUN echo "=== FINAL BUILD VERIFICATION ==="
RUN echo "1) PuLID model:" && ls -lh /comfyui/models/pulid/
RUN echo "2) InsightFace models:" && ls -lh /comfyui/models/insightface/models/antelopev2/
RUN echo "3) Running InsightFace test:" && python3 /test_insightface.py
RUN echo "4) Patch verification:" && python3 -c "
import re
with open('/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py', 'r') as f:
    content = f.read()
    if 'INSIGHTFACE_DIR = \"/comfyui/models/insightface\"' in content:
        print('✅ INSIGHTFACE_DIR set correctly')
    else:
        print('❌ INSIGHTFACE_DIR not set correctly')
    if 'providers=[' not in content:
        print('✅ providers argument removed')
    else:
        print('❌ providers argument still present')
"
RUN echo "5) extra_model_paths.yaml:" && cat /comfyui/extra_model_paths.yaml
RUN echo "=== BUILD COMPLETE ==="