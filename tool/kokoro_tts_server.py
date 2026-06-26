#!/usr/bin/env python3
"""Lumina Kokoro TTS 持久化服务.

模型只加载一次，后续合成通过 stdin/stdout JSON 协议完成.
使用 mlx_audio.tts.generate.generate_audio() 并复用已加载的 model 对象.

协议:
  请求:  {"text": "...", "voice": "af_heart", "speed": 1.0, "lang_code": "a", "output": "/tmp/xxx.wav"}
  响应:  {"ok": true, "file": "/tmp/xxx.wav", "bytes": 12345, "duration_ms": 5150}
  错误:  {"ok": false, "error": "..."}
  退出:  {"quit": true}
"""

import json
import os
import sys

_model_path = (
    os.environ.get("MLX_TTS_MODEL_PATH")
    or os.environ.get("KOKORO_MODEL_PATH")
    or "/Users/trevorwu/.lmstudio/models/mlx-community/Kokoro-82M-bf16"
)

_model = None
_ref_audio_cache = {}
_ref_audio_cache_order = []
_max_ref_audio_cache_entries = 8


def _get_model():
    global _model
    if _model is None:
        from mlx_audio.utils import load_model
        _model = load_model(_model_path)
    return _model


def _resolve_ref_audio(ref_audio):
    if not ref_audio or not isinstance(ref_audio, str):
        return ref_audio

    if not os.path.exists(ref_audio):
        return ref_audio

    from mlx_audio.tts.generate import load_audio

    model = _get_model()
    stat = os.stat(ref_audio)
    key = (ref_audio, stat.st_mtime_ns, stat.st_size, model.sample_rate)
    cached = _ref_audio_cache.get(key)
    if cached is not None:
        return cached

    audio = load_audio(
        ref_audio,
        sample_rate=model.sample_rate,
        volume_normalize=False,
    )
    _ref_audio_cache[key] = audio
    _ref_audio_cache_order.append(key)

    while len(_ref_audio_cache_order) > _max_ref_audio_cache_entries:
        old_key = _ref_audio_cache_order.pop(0)
        _ref_audio_cache.pop(old_key, None)

    return audio


def _synthesize(
    text,
    voice,
    speed,
    lang_code,
    output,
    ref_audio=None,
    ref_text=None,
    instruct=None,
    temperature=None,
    top_p=None,
    top_k=None,
    chunk_length=None,
):
    from mlx_audio.tts.generate import generate_audio

    file_prefix = output.rsplit(".", 1)[0]  # strip extension
    resolved_ref_audio = _resolve_ref_audio(ref_audio)

    # 先尝试完整文本合成
    try:
        _do_generate(
            text,
            voice,
            speed,
            lang_code,
            file_prefix,
            ref_audio=resolved_ref_audio,
            ref_text=ref_text,
            instruct=instruct,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            chunk_length=chunk_length,
        )
        return _check_output(output)
    except Exception as e:
        # 如果失败，按句子切分后逐句合成再拼接
        import re
        import numpy as np
        import soundfile as sf

        sentences = re.split(r'(?<=[.!?;\n])', text.strip())
        sentences = [s.strip() for s in sentences if s.strip()]
        if len(sentences) <= 1:
            # 无法切分，再按空格硬切
            words = text.split()
            mid = len(words) // 2
            if mid > 0:
                sentences = [' '.join(words[:mid]), ' '.join(words[mid:])]
            else:
                raise

        # 逐句合成
        parts = []
        for i, sent in enumerate(sentences):
            part_prefix = f"{file_prefix}_part{i}"
            part_wav = f"{part_prefix}.wav"
            _do_generate(
                sent,
                voice,
                speed,
                lang_code,
                part_prefix,
                ref_audio=resolved_ref_audio,
                ref_text=ref_text,
                instruct=instruct,
                temperature=temperature,
                top_p=top_p,
                top_k=top_k,
                chunk_length=chunk_length,
            )
            if os.path.exists(part_wav):
                audio, sr = sf.read(part_wav)
                parts.append(audio)
                os.unlink(part_wav)

        if not parts:
            raise RuntimeError("All sub-segments failed to synthesize")

        # 拼接
        full = np.concatenate(parts)
        sf.write(output, full, 24000)

        duration_ms = int(len(full) / 24000 * 1000)
        file_size = os.path.getsize(output)
        return {
            "ok": True,
            "file": output,
            "bytes": file_size,
            "duration_ms": duration_ms,
        }


def _do_generate(
    text,
    voice,
    speed,
    lang_code,
    file_prefix,
    ref_audio=None,
    ref_text=None,
    instruct=None,
    temperature=None,
    top_p=None,
    top_k=None,
    chunk_length=None,
):
    from mlx_audio.tts.generate import generate_audio
    import io
    from contextlib import redirect_stdout

    # generate_audio prints verbose output to stdout; redirect to stderr
    # so stdout only carries our JSON responses.
    options = {}
    if temperature is not None:
        options["temperature"] = float(temperature)
    if top_p is not None:
        options["top_p"] = float(top_p)
    if top_k is not None:
        options["top_k"] = int(top_k)
    if chunk_length is not None:
        options["chunk_length"] = int(chunk_length)

    with redirect_stdout(sys.stderr):
        generate_audio(
            text=text,
            model=_get_model(),
            voice=voice,
            speed=speed,
            lang_code=lang_code,
            ref_audio=ref_audio,
            ref_text=ref_text,
            instruct=instruct,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            chunk_length=chunk_length,
            file_prefix=file_prefix,
            audio_format="wav",
            join_audio=True,
            verbose=False,
            play=False,
            **options,
        )


def _check_output(output):
    if not os.path.exists(output):
        raise RuntimeError(f"Output file not created: {output}")
    file_size = os.path.getsize(output)
    if file_size == 0:
        raise RuntimeError("Output file is empty")

    duration_ms = 0
    try:
        import soundfile as sf
        info = sf.info(output)
        duration_ms = int(info.frames / info.samplerate * 1000)
    except Exception:
        pass

    return {
        "ok": True,
        "file": output,
        "bytes": file_size,
        "duration_ms": duration_ms,
    }


def main():
    # 预热：加载模型
    try:
        _get_model()
        sys.stderr.write("TTS server ready (model loaded)\n")
        sys.stderr.flush()
    except Exception as e:
        sys.stderr.write(f"Preload error: {e}\n")
        sys.stderr.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as e:
            print(json.dumps({"ok": False, "error": f"JSON decode: {e}"}), flush=True)
            continue

        if req.get("quit"):
            break

        try:
            # Ensure output path has .wav extension
            output = req["output"]
            if not output.endswith(".wav"):
                output = output + ".wav"

            result = _synthesize(
                text=req["text"],
                voice=req.get("voice", "af_heart"),
                speed=float(req.get("speed", 1.0)),
                lang_code=req.get("lang_code", "a"),
                output=output,
                ref_audio=req.get("ref_audio"),
                ref_text=req.get("ref_text"),
                instruct=req.get("instruct"),
                temperature=req.get("temperature"),
                top_p=req.get("top_p"),
                top_k=req.get("top_k"),
                chunk_length=req.get("chunk_length"),
            )
            print(json.dumps(result), flush=True)
        except Exception as e:
            print(json.dumps({"ok": False, "error": str(e)}), flush=True)


if __name__ == "__main__":
    main()
