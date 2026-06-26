# Local Transcriber

Native macOS-app for lokal transkribering av lydfiler. Appen sender ikke lyd eller tekst til eksterne API-er.

## Kjøring

Forutsetninger på denne maskinen:

- `/Users/po/.local/bin/ffmpeg`
- `/Users/po/.local/bin/mlx_whisper`
- `/Users/po/.local/bin/canary-transcribe`
- lokale Hugging Face-modeller under `~/.cache/huggingface/hub`

Bygg og start appen:

```bash
cd /Users/po/dev/local-transcriber
./script/build_and_run.sh
```

Verifiser at appen bygger og starter:

```bash
./script/build_and_run.sh --verify
```

Kjør tester:

```bash
swift test
```

## Modeller

Støttet i denne versjonen:

- `mlx-community/whisper-large-v3-turbo` via `mlx_whisper`
  - Anbefalt standard for norsk.
  - Bruker `--language no` når språk er Norsk.
  - Kjøres med `--output-format all`, så appen kan lagre `.txt`, `.srt` og `.json`.
- `nvidia/canary-1b-v2` via `canary-transcribe`
  - Kjøres lokalt.
  - Merkes i appen som `Ikke anbefalt for norsk`.
  - Første versjon lagrer tekst fra stdout som `.txt`.

Synlig, men ikke koblet til i denne versjonen:

- `openai/whisper-large-v3-turbo` via Transformers/HF
- `openai/whisper-large-v3` via Transformers/HF

Disse HF-modellene ligger lokalt, men appen har foreløpig ingen lokal Transformers-runner. De er deaktivert i UI-en for å unngå en modellknapp som ser ut til å virke, men ikke gjør det.

## Offline-policy

Appen setter `HF_HUB_OFFLINE=1` og `TRANSFORMERS_OFFLINE=1` for prosessene den starter. Hvis en modell mangler i lokal cache, feiler appen med en tydelig melding i stedet for å laste den ned.

## Arkitektur

- SwiftUI macOS-app i `Sources/LocalTranscriber`.
- CLI-, modell- og prosesslogikk i `Sources/LocalTranscriberCore`.
- `Process` brukes til å kalle lokale verktøy.
- Hver transkribering får en ny midlertidig output-mappe, og appen leser resultatfilene tilbake etter at prosessen er ferdig.
