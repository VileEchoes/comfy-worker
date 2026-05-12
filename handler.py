import runpod
import json, time, base64, os, requests, uuid, subprocess

COMFY_URL = "http://127.0.0.1:8188"

def setup_model_links():
    print("=== DEBUGGING VOLUME MOUNT ===")
    
    # Potential volume paths
    volume_paths = ["/runpod-volume", "/workspace"]
    
    for volume_path in volume_paths:
        print(f"📂 Contents of {volume_path}:")
        try:
            items = os.listdir(volume_path)
            for item in items:
                full_path = os.path.join(volume_path, item)
                if os.path.isdir(full_path):
                    print(f"  📁 {item}/")
                else:
                    print(f"  📄 {item}")
        except Exception as e:
            print(f"  ❌ Error: {e}")
    
    # Create symlinks to ComfyUI model paths
    models_map = {
        f"{volume_path}/checkpoints": "/comfyui/models/checkpoints"
        for volume_path in volume_paths
    }
    models_map.update({
        f"{volume_path}/clip_vision": "/comfyui/models/clip_vision"
        for volume_path in volume_paths
    })
    models_map.update({
        f"{volume_path}/ipadapter": "/comfyui/models/ipadapter"
        for volume_path in volume_paths
    })
    
    for src, dst in models_map.items():
        if os.path.exists(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if os.path.exists(dst):
                if os.path.islink(dst) or os.path.isfile(dst):
                    os.unlink(dst)
                else:
                    os.system(f"rm -rf {dst}")
            os.symlink(src, dst)
            print(f"✅ Linked {src} -> {dst}")

def start_comfy():
    subprocess.Popen([
        "python", "/comfyui/main.py",
        "--listen", "127.0.0.1",
        "--port", "8188"
    ])

def wait_for_comfy(timeout=90):
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(f"{COMFY_URL}/system_stats", timeout=3)
            if r.status_code == 200:
                print("✅ ComfyUI ready")
                return True
        except:
            pass
        time.sleep(2)
    raise RuntimeError("ComfyUI failed to start")

def queue_prompt(workflow):
    payload = {"prompt": workflow, "client_id": str(uuid.uuid4())}
    r = requests.post(f"{COMFY_URL}/prompt", json=payload)
    r.raise_for_status()
    return r.json()["prompt_id"]

def wait_for_result(prompt_id, timeout=300):
    start = time.time()
    while time.time() - start < timeout:
        r = requests.get(f"{COMFY_URL}/history/{prompt_id}")
        history = r.json()
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(2)
    raise TimeoutError("Job timed out")

def get_images_and_cleanup(result):
    images_b64 = []
    for node_output in result["outputs"].values():
        if "images" not in node_output:
            continue
        for img in node_output["images"]:
            path = f"/comfyui/output/{img['filename']}"
            with open(path, "rb") as f:
                images_b64.append(base64.b64encode(f.read()).decode())
            os.remove(path)  # delete immediately after reading
    return images_b64

def inject_inputs(workflow, job_input):
    wf = json.loads(json.dumps(workflow))

    if "prompt" in job_input:
        wf["3"]["inputs"]["text"] = job_input["prompt"]

    if "negative_prompt" in job_input:
        wf["2"]["inputs"]["text"] = job_input["negative_prompt"]

    if "seed" in job_input:
        wf["6"]["inputs"]["seed"] = job_input["seed"]

    ref_filename = None
    if "reference_image" in job_input:
        img_data = base64.b64decode(job_input["reference_image"])
        ref_filename = f"ref_{uuid.uuid4().hex}.png"
        with open(f"/comfyui/input/{ref_filename}", "wb") as f:
            f.write(img_data)
        wf["9"]["inputs"]["image"] = ref_filename

    return wf, ref_filename

def cleanup_input(filename):
    if filename:
        path = f"/comfyui/input/{filename}"
        if os.path.exists(path):
            os.remove(path)

# Startup
with open("/workflow.json") as f:
    BASE_WORKFLOW = json.load(f)

setup_model_links()
start_comfy()
wait_for_comfy()

def handler(job):
    job_input = job["input"]
    ref_filename = None
    try:
        workflow, ref_filename = inject_inputs(BASE_WORKFLOW, job_input)
        prompt_id = queue_prompt(workflow)
        result = wait_for_result(prompt_id)
        if result.get("error"):
            return {"error": str(result["error"])}
        images = get_images_and_cleanup(result)
        return {"images": images}
    except Exception as e:
        return {"error": str(e)}
    finally:
        cleanup_input(ref_filename)

runpod.serverless.start({"handler": handler})

