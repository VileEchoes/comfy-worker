FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Fix numpy and remove conflicting package
RUN pip uninstall comfy_kitchen -y || true && \
    pip install "numpy<2" --no-cache-dir

# Install ComfyUI pinned to stable version
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    cd /comfyui && \
    git checkout v0.3.7 && \
    pip install -r requirements.txt --no-cache-dir

# Install runpod
RUN pip install runpod requests --no-cache-dir

# Install IPAdapter+ custom node
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git

RUN pip install insightface onnxruntime --no-cache-dir

# Create required folders
RUN mkdir -p /comfyui/input /comfyui/output /comfyui/models/checkpoints \
    /comfyui/models/clip_vision /comfyui/models/ipadapter

# Bake models into the image so workers can spawn in any region (no network
# volume needed). CIVITAI_TOKEN is provided as a BuildKit secret to keep it
# out of the final image layers.
RUN --mount=type=secret,id=civitai_token \
    CIVITAI_TOKEN=$(cat /run/secrets/civitai_token) && \
    curl -fL --retry 5 --retry-delay 5 \
        -o /comfyui/models/checkpoints/ponyDiffusionV6XL_v6StartWithThisOne.safetensors \
        "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=pruned&fp=fp16&token=${CIVITAI_TOKEN}"

RUN curl -fL --retry 5 --retry-delay 5 \
        -o /comfyui/models/clip_vision/model.safetensors \
        "https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K/resolve/main/model.safetensors"

RUN --mount=type=secret,id=civitai_token \
    CIVITAI_TOKEN=$(cat /run/secrets/civitai_token) && \
    curl -fL --retry 5 --retry-delay 5 \
        -o /comfyui/models/ipadapter/ip-adapter_sdxl_vit-h.bin \
        "https://civitai.com/api/download/models/177163?type=Model&format=Other&size=full&fp=fp32&token=${CIVITAI_TOKEN}"

COPY workflow.json /workflow.json
COPY handler.py /handler.py

CMD ["python", "-u", "/handler.py"]
