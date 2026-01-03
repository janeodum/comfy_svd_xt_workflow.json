#!/bin/bash
echo "🔍 Setting up models from Network Volume..."

if [ -d "/runpod-volume/models" ]; then
    echo "✅ Network Volume found at /runpod-volume"
    
    # FLUX FP8 checkpoint
    if [ -f "/runpod-volume/models/checkpoints/flux1-dev-fp8.safetensors" ]; then
        ln -sf /runpod-volume/models/checkpoints/flux1-dev-fp8.safetensors /comfyui/models/checkpoints/
        echo "✅ Linked FLUX FP8 model"
    else
        echo "⚠️ FLUX model not found on volume"
    fi
    
    # Wan 2.1 I2V
    if [ -f "/runpod-volume/models/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors" ]; then
        ln -sf /runpod-volume/models/diffusion_models/Wan2.1/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors /comfyui/models/diffusion_models/Wan2.1/
        echo "✅ Linked Wan 2.1 I2V model"
    else
        echo "⚠️ Wan 2.1 model not found on volume"
    fi
    
    # VAE (if present)
    if [ -f "/runpod-volume/models/vae/ae.safetensors" ]; then
        ln -sf /runpod-volume/models/vae/ae.safetensors /comfyui/models/vae/
        echo "✅ Linked VAE"
    fi
    
else
    echo "❌ Network Volume NOT mounted at /runpod-volume"
    echo "   Large models will need to download at runtime (may timeout!)"
fi

echo ""
echo "📁 Model check:"
ls -lh /comfyui/models/checkpoints/*.safetensors 2>/dev/null || echo "   checkpoints: (empty)"
ls -lh /comfyui/models/diffusion_models/Wan2.1/*.safetensors 2>/dev/null || echo "   Wan2.1: (empty)"
ls -lh /comfyui/models/pulid/*.safetensors 2>/dev/null || echo "   pulid: (empty)"