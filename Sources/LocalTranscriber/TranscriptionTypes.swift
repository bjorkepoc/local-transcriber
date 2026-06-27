enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case norwegian
    case english
    case swedish
    case danish
    case auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .norwegian:
            "Norsk"
        case .english:
            "Engelsk"
        case .swedish:
            "Svensk"
        case .danish:
            "Dansk"
        case .auto:
            "Auto"
        }
    }

    var cliCode: String? {
        switch self {
        case .norwegian:
            "no"
        case .english:
            "en"
        case .swedish:
            "sv"
        case .danish:
            "da"
        case .auto:
            nil
        }
    }

    var transformersLanguage: String? {
        switch self {
        case .norwegian:
            "norwegian"
        case .english:
            "english"
        case .swedish:
            "swedish"
        case .danish:
            "danish"
        case .auto:
            nil
        }
    }
}

struct TranscriptionResult: Sendable {
    let text: String
    let srt: String?
    let json: String?
}
