"""FindMyVoice — lightweight voice-to-text backend.

Records from the default mic, transcribes via OpenAI Whisper API or NVIDIA
NeMo Parakeet (local), and pastes the result into the active app.  Exposes a
local HTTP API on localhost:7890 for the SwiftUI frontend.  Hotkey listening is
handled by the Swift app.
"""

import json
import os
import subprocess
import tempfile
import threading
from pathlib import Path

import numpy as np
import sounddevice as sd
from flask import Flask, jsonify, request
from scipy.io import wavfile
from openai import OpenAI

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

CONFIG_DIR = Path.home() / ".findmyvoice"
CONFIG_PATH = CONFIG_DIR / "config.json"

DEFAULT_CONFIG: dict = {
    "api_key": "",
    "api_provider": "openai",
    "openai_model": "whisper-1",
    "openai_language": "auto",
    "nemo_language": "auto",
    "hotkey": "f1",
    "sound_start": "Tink",
    "sound_stop": "Pop",
    "auto_paste": True,
    "auto_capitalize": True,
    "auto_punctuate": True,
}


def _migrate(cfg: dict) -> tuple[dict, bool]:
    """Migrate old config schema to new schema. Returns (cfg, changed)."""
    changed = False

    # provider: "custom" → "openai"
    if cfg.get("api_provider") == "custom":
        cfg["api_provider"] = "openai"
        changed = True

    # old "model" → "openai_model"
    if "model" in cfg:
        old_model = cfg.pop("model")
        if "openai_model" not in cfg:
            allowed = {"whisper-1", "whisper-large-v3", "whisper-large-v3-turbo"}
            cfg["openai_model"] = old_model if old_model in allowed else "whisper-1"
        changed = True

    # old "language" → "openai_language"
    if "language" in cfg:
        old_lang = cfg.pop("language")
        if "openai_language" not in cfg:
            cfg["openai_language"] = old_lang
        cfg.setdefault("nemo_language", "auto")
        changed = True

    # remove obsolete fields
    for field in ("api_base_url",):
        if field in cfg:
            cfg.pop(field)
            changed = True

    return cfg, changed


def load_config() -> dict:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH) as f:
            saved = json.load(f)
        saved, changed = _migrate(saved)
        merged = {**DEFAULT_CONFIG, **saved}
        if changed:
            save_config(merged)
        return merged
    save_config(DEFAULT_CONFIG)
    return dict(DEFAULT_CONFIG)


def save_config(cfg: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)


config = load_config()

# ---------------------------------------------------------------------------
# Audio recording state
# ---------------------------------------------------------------------------

SAMPLE_RATE = 16000
recording = False
audio_frames: list[np.ndarray] = []
stream: sd.InputStream | None = None
lock = threading.Lock()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def play_sound(name: str) -> None:
    """Play a macOS system sound by name (non-blocking)."""
    path = f"/System/Library/Sounds/{name}.aiff"
    if os.path.exists(path):
        subprocess.Popen(["afplay", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def paste_text(text: str) -> None:
    """Copy *text* to the clipboard and simulate Cmd+V."""
    process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
    process.communicate(text.encode("utf-8"))

    subprocess.run(
        [
            "osascript",
            "-e",
            'tell application "System Events" to keystroke "v" using command down',
        ],
        check=False,
    )


def post_process(text: str) -> str:
    """Apply auto-capitalize and auto-punctuate."""
    if not text:
        return text
    if config.get("auto_capitalize", True):
        text = text[0].upper() + text[1:]
    if config.get("auto_punctuate", True):
        if text[-1] not in ".!?,:;":
            text += "."
    return text


# ---------------------------------------------------------------------------
# Recording
# ---------------------------------------------------------------------------


def _audio_callback(indata: np.ndarray, frames: int, time_info, status) -> None:
    audio_frames.append(indata.copy())


def start_recording() -> bool:
    global recording, stream, audio_frames
    with lock:
        if recording:
            return False
        audio_frames = []
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype="float32",
            callback=_audio_callback,
        )
        stream.start()
        recording = True
    play_sound(config.get("sound_start", "Tink"))
    return True


def stop_recording() -> bool:
    global recording, stream
    with lock:
        if not recording:
            return False
        if stream is not None:
            stream.stop()
            stream.close()
            stream = None
        recording = False
    play_sound(config.get("sound_stop", "Pop"))
    threading.Thread(target=_transcribe_and_paste, daemon=True).start()
    return True


def _transcribe_and_paste() -> None:
    if not audio_frames:
        return

    # Write wav to a temp file
    audio = np.concatenate(audio_frames, axis=0)
    audio_int16 = np.int16(audio * 32767)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    wavfile.write(tmp.name, SAMPLE_RATE, audio_int16)
    tmp.close()

    try:
        text = transcribe(tmp.name)
        text = post_process(text)
        if text and config.get("auto_paste", True):
            paste_text(text)
    finally:
        os.unlink(tmp.name)


# ---------------------------------------------------------------------------
# Transcription
# ---------------------------------------------------------------------------

_nemo_model = None


def transcribe_nemo(audio_path: str, language: str) -> str:
    global _nemo_model
    try:
        import nemo.collections.asr as nemo_asr
    except ImportError:
        return "[Error] NeMo is not installed. Run: pip install nemo_toolkit['asr']"

    if _nemo_model is None:
        _nemo_model = nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt-0.6b-v3")

    output = _nemo_model.transcribe([audio_path])
    return output[0].text


def transcribe_openai(wav_path: str) -> str:
    api_key = config.get("api_key", "")
    if not api_key:
        print("[FindMyVoice] No API key configured.")
        return ""

    client = OpenAI(api_key=api_key)

    language = config.get("openai_language", "auto")
    kwargs: dict = {"model": config.get("openai_model", "whisper-1"), "file": open(wav_path, "rb")}
    if language and language != "auto":
        kwargs["language"] = language

    try:
        transcript = client.audio.transcriptions.create(**kwargs)
        return transcript.text.strip()
    except Exception as e:
        print(f"[FindMyVoice] Transcription error: {e}")
        return ""


def transcribe(wav_path: str) -> str:
    provider = config.get("api_provider", "openai")
    if provider == "nemo":
        language = config.get("nemo_language", "auto")
        return transcribe_nemo(wav_path, language)
    return transcribe_openai(wav_path)


# ---------------------------------------------------------------------------
# Flask HTTP API
# ---------------------------------------------------------------------------

app = Flask(__name__)


@app.get("/config")
def get_config():
    return jsonify(config)


@app.post("/config")
def update_config():
    global config
    data = request.get_json(force=True)
    config.update(data)
    save_config(config)
    return jsonify(config)


@app.get("/status")
def get_status():
    return jsonify({"recording": recording})


@app.post("/start")
def api_start():
    ok = start_recording()
    return jsonify({"recording": True, "started": ok})


@app.post("/stop")
def api_stop():
    ok = stop_recording()
    return jsonify({"recording": False, "stopped": ok})


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("[FindMyVoice] Starting backend on http://localhost:7890")
    app.run(host="127.0.0.1", port=7890, threaded=True)
