# Contributing

Thanks for considering a contribution to Local Transcriber.

## Project Direction

Local Transcriber is a local-first macOS app. The core promise is simple: users should be able to transcribe audio on their own Mac without sending audio or text to an external API.

Contributions should preserve that default. Network-backed features are only appropriate when they are explicit, optional, and clearly documented.

## Development

Build and run the app:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```

Run tests:

```bash
swift test
```

## Pull Requests

Please include:

- What changed.
- Why it changed.
- How you tested it.
- Any new setup requirements.

Keep changes focused. Small, clear PRs are easier to review.
