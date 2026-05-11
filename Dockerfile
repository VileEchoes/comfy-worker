FROM runpod/pytorch:2.2.0-py3.10-cuda12.1.1-devel-ubuntu22.04

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    cd /comfyui && \
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

# Create extra model paths config for network volume
RUN echo "base_path: /runpod-volume/" > /extra_model_paths.yaml && \
    echo "checkpoints: /runpod-volume/models/checkpoints/" >> /extra_model_paths.yaml && \
    echo "clip_vision: /runpod-volume/models/clip_vision/" >> /extra_model_paths.yaml && \
    echo "ipadapter: /runpod-volume/models/ipadapter/" >> /extra_model_paths.yaml

COPY workflow.json /workflow.json
COPY handler.py /handler.py

CMD ["python", "-u", "/handler.py"]
