public enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case norwegian
    case english
    case swedish
    case danish
    case auto

    public var id: String { rawValue }

    public var displayName: String {
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

    public var whisperCode: String? {
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

    public var canaryCode: String? {
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
}
