# WhisperGUI (SwiftUI MVP)

Minimal macOS GUI for running `whisper.cpp` locally and offline.

## Prereqs
- Homebrew packages: `ffmpeg` and `whisper-cpp`
- A whisper.cpp model file (e.g. `ggml-base.en.bin`)

Install deps:

```bash
brew install ffmpeg whisper-cpp
```

Download a model (example):

```bash
curl -L -o ggml-base.en.bin "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
```

## Run

```bash
swift run
```

In the app:
- Pick the model file (`.bin`)
- Pick a media file (`.mp4`, `.mov`, `.m4a`, `.wav`, `.mp3`, etc.)
- Click **Transcribe**

The transcript appears in the editor and is also written to a temp `.txt` file shown in Status.
