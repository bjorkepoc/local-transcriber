import UniformTypeIdentifiers

public enum TranscriptOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case txt
    case srt
    case json

    public var id: String { rawValue }
    public var fileExtension: String { rawValue }

    public var contentType: UTType {
        switch self {
        case .txt:
            .plainText
        case .srt:
            UTType(filenameExtension: "srt") ?? .plainText
        case .json:
            .json
        }
    }
}
