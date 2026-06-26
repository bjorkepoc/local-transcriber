public struct TranscriptionResult: Sendable {
    public let text: String
    public let outputs: [TranscriptOutputFormat: String]

    public init(text: String, outputs: [TranscriptOutputFormat: String]) {
        self.text = text
        self.outputs = outputs
    }
}
