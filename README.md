# Local Transcriber

Native macOS-app for lokal transkribering med `mlx-community/whisper-large-v3-turbo` via `mlx_whisper`. Appen sender ikke lyd eller tekst til eksterne API-er.

## Requirements

- macOS 14 or newer.
- Swift toolchain compatible with SwiftPM `swift-tools-version: 6.3`.
- `mlx_whisper` available in `PATH`.
- `mlx-community/whisper-large-v3-turbo` downloaded locally.

The app intentionally does not download models at runtime. If the model is missing, `mlx_whisper` fails instead of the app silently using the network.

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

## Offline Policy

Appen setter `HF_HUB_OFFLINE=1`, `TRANSFORMERS_OFFLINE=1` og `HF_HUB_DISABLE_TELEMETRY=1` for prosessen den starter. Hvis modellen mangler lokalt, feiler `mlx_whisper` i stedet for at appen laster den ned.

## License

MIT. See [LICENSE](LICENSE).
