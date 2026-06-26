# Local Transcriber

Local Transcriber is a small native macOS app for offline audio transcription with MLX Whisper. It gives you a simple SwiftUI interface for choosing an audio or video file, running local transcription, and saving the generated transcript files.

The app does not send audio or transcript text to external APIs. It is currently Norwegian-first and uses `mlx-community/whisper-large-v3-turbo` through `mlx_whisper`.

![Local Transcriber macOS app](docs/screenshot.png)

## Features

- Native SwiftUI macOS app.
- Pick an audio or video file from Finder.
- Transcribe locally with `mlx_whisper`.
- Save TXT output.
- Save generated SRT and JSON output.
- Offline Hugging Face execution environment:
  - `HF_HUB_OFFLINE=1`
  - `TRANSFORMERS_OFFLINE=1`
  - `HF_HUB_DISABLE_TELEMETRY=1`

## Requirements

- macOS 14 or newer.
- Swift toolchain compatible with SwiftPM `swift-tools-version: 6.3`.
- `mlx_whisper` available in `PATH`.
- `mlx-community/whisper-large-v3-turbo` downloaded locally.

The app intentionally does not download models at runtime. If the model is missing, `mlx_whisper` fails instead of the app silently using the network.

## Recommended Local Setup

Verify MLX Whisper:

```bash
uvx --python 3.12 --from mlx-whisper mlx_whisper --help
```

Download the recommended model with your preferred Hugging Face tooling:

```bash
uvx --from huggingface_hub hf download mlx-community/whisper-large-v3-turbo
```

## Run

```bash
git clone https://github.com/bjorkepoc/local-transcriber.git
cd local-transcriber
./script/build_and_run.sh
```

Verify that the app builds and launches:

```bash
./script/build_and_run.sh --verify
```

Run tests:

```bash
swift test
```

## Model

Local Transcriber currently runs one local model:

- Model: `mlx-community/whisper-large-v3-turbo`
- Tool: `mlx_whisper`
- Recommended default for Norwegian.
- Uses `--language no` when Norwegian is selected.
- Runs with `--output-format all`, allowing the app to save TXT, SRT, and JSON output.

## Architecture

This is a simple Swift Package Manager macOS app:

- `Sources/LocalTranscriber/App` contains the app entry point.
- `Sources/LocalTranscriber/Views` contains the SwiftUI UI.
- `Sources/LocalTranscriber/ViewModels` coordinates UI state and save/copy actions.
- `Sources/LocalTranscriber/Services` runs the local transcription process.
- `Sources/LocalTranscriber/TranscriptionTypes.swift` defines languages and result types.
- `Tests/LocalTranscriberTests` covers argument construction and language behavior.

The app uses `Process` to launch `mlx_whisper`. Each transcription run writes into a temporary output directory; the app reads the generated files back into memory and removes the temporary directory afterward.

## Privacy

Local Transcriber is designed for local-first transcription:

- No app server.
- No API key.
- No audio upload.
- No transcript upload.
- No automatic model downloads from the app process.

You are still responsible for how the external tools installed on your machine are configured. The app sets offline environment variables for the child process it starts.

## Current Limitations

- No packaged release artifact yet; build from source with SwiftPM.
- No automatic dependency installation.
- No transcript history or project library.
- UI copy is currently Norwegian.
- MLX Whisper is the only backend wired into the app.

## Contributing

Issues and pull requests are welcome. Useful contributions include:

- Better setup documentation for different Mac configurations.
- More robust error messages for missing tools or models.
- Packaged release builds.
- Additional local transcription backends.
- English UI localization.

Please keep the project local-first. Features that require uploading audio or transcript data should be optional and explicit.

## License

MIT. See [LICENSE](LICENSE).
