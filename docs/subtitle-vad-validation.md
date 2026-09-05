# Historical experiment — VAD removed from subtitle generation

The app now segments subtitles by text. Sherpa and its model are no longer runtime
dependencies. Measurements below describe the previous experiment, not the current app.

# Subtitle VAD integration validation

Implementation: pinned sherpa_onnx 1.13.7, bundled k2-fsa Silero v4 (16 kHz),
CPU single thread, worker isolate. Whisper transcription remains unchanged.
Failure to initialize/run the optional detector falls back to energy detection.
No microphone, network inference, or playback-time analysis is introduced.

## Local measurements

macOS host, Flutter native test process. Sample: public whisper.cpp `samples/jfk.wav`
(approximately 11 seconds), downloaded from:
https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/samples/jfk.wav

| Input | Silero elapsed | Energy elapsed | Silero boundaries (ms) | Energy boundaries (ms) |
| --- | --- | --- | --- | --- |
| Original | 899 ms | 7 ms | 298, 3274, 5386, 8170 | 320, 3280, 5400, 8180 |
| Added Gaussian noise, sigma 700 PCM16, Python random seed 42 | 110 ms | 8 ms | 298, 3274, 5386, 8170 | none |

Each measurement includes model creation and file reading. Different first-load
and OS cache states make these unsuitable for comparing clean/noisy speed.
RSS increased about 26–27 MB in the native test process. This is not an isolated
peak allocation measurement; reported process peak includes the Flutter harness.
There is no mobile latency, battery, or manually annotated accuracy result yet.
The noisy sample is derived from real speech, not a separate real-world noise corpus.

The clean recording shows little benefit, while this controlled noisy recording
shows why a speech detector can outperform a fixed energy threshold. It does not
establish universal accuracy or music robustness.

## Build impact

macOS debug build passed. Existing app artifact before integration: 213508 KiB;
after integration: 273268 KiB (~58 MiB larger). This is an approximate comparison
against an existing debug artifact, not an isolated release-size A/B measurement.
The bundled model is 643854 bytes; most added size comes from the native runtime.

The existing cupertino-native-better Swift package requires macOS 11.0. The app
and Podfile minimum were aligned from 10.15 to 11.0 to resolve the build conflict.
Android/iOS builds and release installation sizes still need platform validation.

## Historical configuration

sherpa_onnx 1.13.7, k2-fsa Silero v4 16 kHz, one CPU thread, 300 ms minimum silence.
Model SHA-256: 9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6.
Source: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx

Current regression coverage verifies sentence/clause boundaries, abbreviations,
URLs, decimals, complete text retention, timestamp invariance and buffering sync.
