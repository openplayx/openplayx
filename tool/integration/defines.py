#!/usr/bin/env python3
"""Writes build/integration-defines.json for the integration tests.

Every live service is required (integration_test/support/live_services.dart):
this script fails, naming what is missing, instead of writing partial defines.

Inputs, run from the openplayx directory:
  tool/source_services/defines.local.json  written by tool/source_services/bootstrap.py
  ../design/.env                         SMB_USER, SMB_PASSWORD (the movie share)
Optional environment overrides:
  MOVIE_SMB_ADDRESS  default smb://<SOURCE_HOST>/movie
  OLLAMA_ENDPOINT    default http://localhost:11434/v1
  OLLAMA_MODEL       default openplayx-it (made by `make integration-ollama`)
  ASR_MODEL_DIR      default ~/.cache/openplayx-asr-models (ggml-tiny.bin is
                     downloaded there and checked when missing)
"""
import hashlib
import json
import os
import sys
import urllib.request

TINY = "ggml-tiny.bin"
TINY_SHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
TINY_URL = f"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{TINY}"


def fail(message):
    sys.exit(f"integration-defines: {message}")


def read_env(path):
    values = {}
    if not os.path.exists(path):
        return values
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.removeprefix("export ").split("=", 1)
        values[key.strip()] = value.strip().strip("'\"")
    return values


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def ensure_tiny(directory):
    path = os.path.join(directory, TINY)
    if os.path.exists(path) and sha256(path) == TINY_SHA256:
        return
    os.makedirs(directory, exist_ok=True)
    print(f"downloading {TINY_URL}")
    urllib.request.urlretrieve(TINY_URL, path + ".part")
    if sha256(path + ".part") != TINY_SHA256:
        os.remove(path + ".part")
        fail(f"{TINY} checksum mismatch")
    os.replace(path + ".part", path)


def main():
    services_path = "tool/source_services/defines.local.json"
    if not os.path.exists(services_path):
        fail(f"{services_path} missing: run tool/source_services/bootstrap.py "
             "(tool/source_services/README.md)")
    defines = json.load(open(services_path, encoding="utf-8"))
    defines.pop("SOURCE_SERVICES", None)
    host = defines.get("SOURCE_HOST")
    if not host:
        fail(f"SOURCE_HOST missing in {services_path}")
    env = {**read_env("../design/.env"), **os.environ}
    missing = [k for k in ("SMB_USER", "SMB_PASSWORD") if not env.get(k)]
    if missing:
        fail(f"set {', '.join(missing)} in ../design/.env (the movie SMB share)")
    asr_dir = os.path.expanduser(
        env.get("ASR_MODEL_DIR", "~/.cache/openplayx-asr-models"))
    ensure_tiny(asr_dir)
    defines.update({
        "MOVIE_SMB_ADDRESS": env.get("MOVIE_SMB_ADDRESS", f"smb://{host}/movie"),
        "MOVIE_SMB_USER": env["SMB_USER"],
        "MOVIE_SMB_PASSWORD": env["SMB_PASSWORD"],
        "OLLAMA_ENDPOINT": env.get("OLLAMA_ENDPOINT", "http://localhost:11434/v1"),
        "OLLAMA_MODEL": env.get("OLLAMA_MODEL", "openplayx-it"),
        "ASR_MODEL_DIR": asr_dir,
    })
    os.makedirs("build", exist_ok=True)
    out = "build/integration-defines.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(defines, f, indent=2)
    os.chmod(out, 0o600)
    print(f"wrote {out} (contains credentials; git-ignored)")


main()
