public enum TranscriptionModel: String, CaseIterable, Identifiable, Sendable {
    case mlxWhisperLargeV3Turbo
    case hfWhisperLargeV3Turbo
    case hfWhisperLargeV3
    case canary1BV2

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mlxWhisperLargeV3Turbo:
            "Whisper large-v3-turbo (MLX, anbefalt)"
        case .hfWhisperLargeV3Turbo:
            "Whisper large-v3-turbo (Transformers/HF)"
        case .hfWhisperLargeV3:
            "Whisper large-v3 (Transformers/HF)"
        case .canary1BV2:
            "NVIDIA Canary 1B v2"
        }
    }

    public var runnerKind: RunnerKind {
        switch self {
        case .mlxWhisperLargeV3Turbo:
            .mlxWhisper
        case .canary1BV2:
            .canary
        case .hfWhisperLargeV3Turbo, .hfWhisperLargeV3:
            .unavailable
        }
    }

    public var isRunnable: Bool {
        runnerKind != .unavailable
    }

    public var defaultLanguage: TranscriptionLanguage {
        switch self {
        case .mlxWhisperLargeV3Turbo, .hfWhisperLargeV3Turbo, .hfWhisperLargeV3:
            .norwegian
        case .canary1BV2:
            .english
        }
    }

    public var repositoryID: String? {
        switch self {
        case .mlxWhisperLargeV3Turbo:
            "mlx-community/whisper-large-v3-turbo"
        case .hfWhisperLargeV3Turbo:
            "openai/whisper-large-v3-turbo"
        case .hfWhisperLargeV3:
            "openai/whisper-large-v3"
        case .canary1BV2:
            "nvidia/canary-1b-v2"
        }
    }

    public var notice: String? {
        switch self {
        case .mlxWhisperLargeV3Turbo:
            "Anbefalt standard for norsk."
        case .canary1BV2:
            "Ikke anbefalt for norsk"
        case .hfWhisperLargeV3Turbo, .hfWhisperLargeV3:
            unavailableReason
        }
    }

    public var unavailableReason: String {
        switch self {
        case .hfWhisperLargeV3Turbo, .hfWhisperLargeV3:
            "Denne appversjonen har ikke en lokal Transformers/HF-runner ennå. Modellen er synlig fordi den finnes lokalt, men transkribering er ikke koblet til."
        case .mlxWhisperLargeV3Turbo, .canary1BV2:
            ""
        }
    }
}

public enum RunnerKind: Sendable {
    case mlxWhisper
    case canary
    case unavailable
}
