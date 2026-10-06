"""Мини-клиент ComfyUI (только стандартная библиотека): загрузка картинки, запуск графа, получение результатов.

Сервер ComfyUI запускается локально (127.0.0.1:8188). Всё происходит на этом ПК: в сеть ничего не отправляется.
"""
import json
import os
import time
import urllib.parse
import urllib.request
import uuid

HOST = os.environ.get("COMFY_HOST", "http://127.0.0.1:8188")


def _req(path, data=None, headers=None, method=None):
    req = urllib.request.Request(HOST + path, data=data, headers=headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read()


def alive():
    try:
        _req("/system_stats")
        return True
    except Exception:
        return False


def object_info(node):
    return json.loads(_req("/object_info/" + urllib.parse.quote(node)))


def upload_image(path, name=None):
    name = name or os.path.basename(path)
    boundary = uuid.uuid4().hex
    body = []
    with open(path, "rb") as f:
        content = f.read()
    for field, value in (("overwrite", "true"), ("type", "input")):
        body.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"\r\n\r\n{value}\r\n".encode())
    body.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\nContent-Type: image/png\r\n\r\n".encode())
    body.append(content)
    body.append(f"\r\n--{boundary}--\r\n".encode())
    res = json.loads(_req("/upload/image", b"".join(body), {"Content-Type": f"multipart/form-data; boundary={boundary}"}))
    return res["name"]


def run(prompt, timeout=1800):
    """Ставит граф в очередь и ждёт завершения. Возвращает history-запись."""
    cid = uuid.uuid4().hex
    res = json.loads(_req("/prompt", json.dumps({"prompt": prompt, "client_id": cid}).encode(), {"Content-Type": "application/json"}))
    pid = res["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < timeout:
        hist = json.loads(_req("/history/" + pid))
        if pid in hist:
            h = hist[pid]
            st = h.get("status", {})
            if st.get("status_str") == "error":
                raise RuntimeError(json.dumps(st.get("messages", []), ensure_ascii=False)[:3000])
            if st.get("completed"):
                h["_seconds"] = round(time.time() - t0, 1)
                return h
        time.sleep(1.0)
    raise TimeoutError(pid)


def outputs(hist, kind="images"):
    files = []
    for node_out in hist.get("outputs", {}).values():
        for f in node_out.get(kind, []) or []:
            files.append(f)
    return files


def fetch(file_info, dest_dir):
    q = urllib.parse.urlencode({"filename": file_info["filename"], "subfolder": file_info.get("subfolder", ""), "type": file_info.get("type", "output")})
    data = _req("/view?" + q)
    os.makedirs(dest_dir, exist_ok=True)
    out = os.path.join(dest_dir, file_info["filename"])
    with open(out, "wb") as f:
        f.write(data)
    return out
