FROM runpodpytorch2.2.0-py3.10-cuda12.1.1-devel-ubuntu22.04

# Install ComfyUI
RUN git clone httpsgithub.comcomfyanonymousComfyUI.git comfyui && 
cd comfyui && 
pip install -r requirements.txt --no-cache-dir

# Install runpod
RUN pip install runpod requests --no-cache-dir

# Install IPAdapter+ custom node
RUN cd comfyuicustom_nodes && 
git clone httpsgithub.comcubiqComfyUI_IPAdapter_plus.git

RUN pip install insightface onnxruntime --no-cache-dir

# Create required folders
RUN mkdir -p comfyuiinput comfyuioutput comfyuimodelscheckpoints 
comfyuimodelsclip_vision comfyuimodelsipadapter

# Create extra model paths config for network volume
RUN echo base_path runpod-volume  extra_model_paths.yaml && 
echo checkpoints runpod-volumemodelscheckpoints  extra_model_paths.yaml && 
echo clip_vision runpod-volumemodelsclip_vision  extra_model_paths.yaml && 
echo ipadapter runpod-volumemodelsipadapter  extra_model_paths.yaml

COPY workflow.json workflow.json
COPY handler.py handler.py

CMD [python, -u, handler.py]
