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

COPY workflow.json /workflow.json
COPY handler.py /handler.py

CMD ["python", "-u", "/handler.py"]
