import Foundation

public struct TranscriptionRequest: Sendable {
    public let audioFile: URL
    public let model: TranscriptionModel
    public let language: TranscriptionLanguage

    public init(audioFile: URL, model: TranscriptionModel, language: TranscriptionLanguage) {
        self.audioFile = audioFile
        self.model = model
        self.language = language
    }
}
