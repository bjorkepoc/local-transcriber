import Foundation

public enum TranscriptionError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case missingTool(name: String, searchedPaths: [String])
    case missingModel(repositoryID: String, expectedPath: String)
    case unsupportedModel(String)
    case invalidAudioFile(String)
    case processFailed(tool: String, code: Int32, output: String)
    case missingOutput(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "Fant ikke lydfilen: \(path)"
        case .missingTool(let name, let searchedPaths):
            "Fant ikke \(name). Sjekket: \(searchedPaths.joined(separator: ", "))"
        case .missingModel(let repositoryID, let expectedPath):
            "Fant ikke lokal modell \(repositoryID). Forventet cache under \(expectedPath). Appen laster ikke ned modeller automatisk."
        case .unsupportedModel(let message):
            message
        case .invalidAudioFile(let output):
            "ffmpeg kunne ikke lese lydfilen. \(output)"
        case .processFailed(let tool, let code, let output):
            "\(tool) feilet med kode \(code). \(output)"
        case .missingOutput(let message):
            message
        }
    }
}
