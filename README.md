# Local Transcriber

Native macOS-app for lokal transkribering med lokale modeller. Appen sender ikke lyd eller tekst til eksterne API-er.

## Requirements

- macOS 14 or newer.
- Swift toolchain compatible with SwiftPM `swift-tools-version: 6.3`.
- `mlx_whisper` available in `PATH`.
- `canary-transcribe` available in `PATH` for NVIDIA Canary.
- `mlx-community/whisper-large-v3-turbo` downloaded locally for the recommended default model.

The app intentionally does not download models at runtime. If a model is missing, the local command fails instead of the app silently using the network.

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

## Models

Local Transcriber shows the downloaded local transcription models:

- `mlx-community/whisper-large-v3-turbo`
  - Tool: `mlx_whisper`
  - Recommended default for Norwegian.
  - Produces TXT, SRT and JSON when `mlx_whisper` creates those files.
- `nvidia/canary-1b-v2`
  - Tool: `canary-transcribe`
  - Runs locally.
  - Marked in the UI as not recommended for Norwegian.
  - Produces TXT output in this app.
- `openai/whisper-large-v3-turbo`
  - Downloaded locally.
  - Visible in the app, but disabled until a local Transformers/HF runner is added.
- `openai/whisper-large-v3`
  - Downloaded locally.
  - Visible in the app, but disabled until a local Transformers/HF runner is added.

The app also accepts extra `mlx_whisper` model IDs or local MLX model directories in the model field. Separate multiple custom models with commas.

When more than one runnable model is selected, the app starts one local run per model and shows:

- a combined comparison view
- one result view per model
- TXT export for the current view
- SRT and JSON export for the selected model result

The MLX runner uses `--output-format all`, allowing the app to save TXT, SRT, and JSON output when `mlx_whisper` creates those files. It also keeps the selected language flag, for example `--language no` when Norwegian is selected.

## Offline Policy

Appen setter `HF_HUB_OFFLINE=1`, `TRANSFORMERS_OFFLINE=1` og `HF_HUB_DISABLE_TELEMETRY=1` for prosessene den starter. Hvis modellen mangler lokalt, feiler kommandoen i stedet for at appen laster den ned.

## License

MIT. See [LICENSE](LICENSE).
