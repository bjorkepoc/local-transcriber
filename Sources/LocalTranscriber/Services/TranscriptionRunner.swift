import Foundation

enum TranscriptionRunner {
    static func transcribe(
        audioFile: URL,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try ensureAudioFileExists(audioFile)
            return try runMLXWhisper(audioFile: audioFile, language: language, status: status)
        }.value
    }

    static func mlxWhisperArguments(
        audioFile: URL,
        language: TranscriptionLanguage,
        outputDirectory: URL
    ) -> [String] {
        var arguments = [
            "--model", "mlx-community/whisper-large-v3-turbo",
            "--output-format", "all",
            "--output-dir", outputDirectory.path,
            "--output-name", "transcript"
        ]

        if let languageCode = language.cliCode {
            arguments.append(contentsOf: ["--language", languageCode])
        }

        arguments.append(audioFile.path)
        return arguments
    }

    private static func runMLXWhisper(
        audioFile: URL,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalTranscriber-mlx-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        status("Kjører MLX Whisper lokalt")
        let arguments = Self.mlxWhisperArguments(
            audioFile: audioFile,
            language: language,
            outputDirectory: outputDirectory
        )
        let execution = try runProcess(arguments: arguments)

        guard execution.code == 0 else {
            let output = execution.output.count > 1_200
                ? String(execution.output.suffix(1_200))
                : execution.output
            throw TranscriptionError.processFailed(
                code: execution.code,
                output: output
            )
        }

        status("Leser transkripsjonsfiler")
        let textURL = outputDirectory.appendingPathComponent("transcript.txt")
        let srtURL = outputDirectory.appendingPathComponent("transcript.srt")
        let jsonURL = outputDirectory.appendingPathComponent("transcript.json")

        guard FileManager.default.fileExists(atPath: textURL.path) else {
            throw TranscriptionError.missingOutput
        }

        let text = try String(contentsOf: textURL, encoding: .utf8)
        let srt = FileManager.default.fileExists(atPath: srtURL.path)
            ? try String(contentsOf: srtURL, encoding: .utf8)
            : nil
        let json = FileManager.default.fileExists(atPath: jsonURL.path)
            ? try String(contentsOf: jsonURL, encoding: .utf8)
            : nil

        return TranscriptionResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines), srt: srt, json: json)
    }

    private static func ensureAudioFileExists(_ audioFile: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: audioFile.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else {
            throw TranscriptionError.fileNotFound(audioFile.path)
        }
    }

    private static func runProcess(arguments: [String]) throws -> (code: Int32, output: String) {
        let outputPipe = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["mlx_whisper"] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["HF_HUB_OFFLINE"] = "1"
        environment["TRANSFORMERS_OFFLINE"] = "1"
        environment["HF_HUB_DISABLE_TELEMETRY"] = "1"
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()

        let output = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (process.terminationStatus, output)
    }
}

private enum TranscriptionError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case processFailed(code: Int32, output: String)
    case missingOutput

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "Fant ikke lydfilen: \(path)"
        case .processFailed(let code, let output):
            "mlx_whisper feilet med kode \(code). \(output)"
        case .missingOutput:
            "MLX Whisper fullførte, men laget ikke transcript.txt."
        }
    }
}
