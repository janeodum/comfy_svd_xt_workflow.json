# Dockerfile for RunPod ComfyUI Worker
# With Network Volume support for large models

FROM runpod/worker-comfyui:5.5.0-base

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg curl ca-certificates aria2 wget \
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
# CRITICAL FIX: Download official InsightFace models
# The previous URLs were incorrect/missing files
# ============================================================
RUN echo "Downloading official InsightFace antelopev2 models..." && \
    cd /comfyui/models/insightface/models/antelopev2 && \
    # Download official models from InsightFace GitHub releases
    wget -q https://github.com/deepinsight/insightface/releases/download/v0.7/det_10g.onnx -O det_10g.onnx && \
    wget -q https://github.com/deepinsight/insightface/releases/download/v0.7/2d106det.onnx -O 2d106det.onnx && \
    wget -q https://github.com/deepinsight/insightface/releases/download/v0.7/genderage.onnx -O genderage.onnx && \
    wget -q https://github.com/deepinsight/insightface/releases/download/v0.7/1k3d68.onnx -O 1k3d68.onnx && \
    wget -q https://github.com/deepinsight/insightface/releases/download/v0.7/glintr100.onnx -O glintr100.onnx && \
    echo "✅ InsightFace models downloaded successfully" && \
    ls -la

# ============================================================
# FIX: Patch InsightFace API compatibility in PuLID
# Newer InsightFace versions don't accept 'providers' in __init__
# We remove the providers argument - InsightFace will use default
# ============================================================
RUN python3 - <<'PY'
import re
path = "/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove providers argument from FaceAnalysis call
patched = re.sub(r",\s*providers=\[.*?\]", "", content)

with open(path, "w", encoding="utf-8") as f:
    f.write(patched)

print("✅ Patched InsightFace providers argument")
PY

# ============================================================
# ADDITIONAL FIX: Create a test script to verify InsightFace works
# ============================================================
RUN python3 - <<'PY'
import os
import sys

# Set environment variable for InsightFace
os.environ['INSIGHTFACE_ROOT'] = '/comfyui/models/insightface'
os.environ['INSIGHTFACE_MODELS_ROOT'] = '/comfyui/models/insightface'

print("Testing InsightFace model loading...")

try:
    import insightface
    print(f"InsightFace version: {insightface.__version__}")
    
    # Test if models exist
    model_dir = "/comfyui/models/insightface/models/antelopev2"
    if os.path.exists(model_dir):
        files = os.listdir(model_dir)
        print(f"Models found in {model_dir}: {files}")
        
        # Check for required models
        required = ['det_10g.onnx', '2d106det.onnx', 'genderage.onnx', '1k3d68.onnx', 'glintr100.onnx']
        missing = [f for f in required if f not in files]
        if missing:
            print(f"⚠️ Missing models: {missing}")
        else:
            print("✅ All required models found")
    else:
        print(f"❌ Model directory not found: {model_dir}")
        
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PY

# Create InsightFace cache directory and symlink
RUN mkdir -p /root/.insightface && \
    # Remove existing models directory if it exists
    rm -rf /root/.insightface/models && \
    # Create symlink to our baked models
    ln -sf /comfyui/models/insightface/models /root/.insightface/models && \
    echo "✅ InsightFace cache directory configured"

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
ENV INSIGHTFACE_MODELS_ROOT=/comfyui/models/insightface
ENV EXTRA_MODEL_PATHS_CONFIG=/comfyui/extra_model_paths.yaml

# ============================================================
# 7) FINAL TEST SCRIPT
# Create a script to test InsightFace at container startup
# ============================================================
RUN cat > /test_insightface.py << 'EOF'
#!/usr/bin/env python3
import os
import sys

# Set environment variables
os.environ['INSIGHTFACE_ROOT'] = '/comfyui/models/insightface'
os.environ['INSIGHTFACE_MODELS_ROOT'] = '/comfyui/models/insightface'

print("=== Testing InsightFace ===")

try:
    # Test 1: Check if models exist
    model_path = "/comfyui/models/insightface/models/antelopev2"
    if not os.path.exists(model_path):
        print(f"❌ Model directory not found: {model_path}")
        sys.exit(1)
    
    files = os.listdir(model_path)
    print(f"Models in {model_path}: {files}")
    
    # Test 2: Try to import and initialize FaceAnalysis
    print("\nTesting FaceAnalysis initialization...")
    from insightface.app import FaceAnalysis
    
    app = FaceAnalysis(name='antelopev2', root='/comfyui/models/insightface')
    print(f"✅ FaceAnalysis created successfully")
    
    # Test 3: Try to prepare the model
    app.prepare(ctx_id=0, det_size=(640, 640))
    print("✅ FaceAnalysis.prepare() succeeded")
    
    print("\n✅ All InsightFace tests passed!")
    
except Exception as e:
    print(f"❌ Error during test: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

RUN chmod +x /test_insightface.py

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# 8) BUILD VERIFICATION
# ============================================================
RUN echo "=== FINAL BUILD VERIFICATION ===" && \
    echo "PuLID model:" && (ls -lh /comfyui/models/pulid/ || echo "  (empty)") && \
    echo "" && \
    echo "InsightFace models:" && (ls -lh /comfyui/models/insightface/models/antelopev2/ || echo "  (empty)") && \
    echo "" && \
    echo "Running InsightFace test..." && \
    python3 /test_insightface.py && \
    echo "" && \
    echo "=== BUILD COMPLETE ==="