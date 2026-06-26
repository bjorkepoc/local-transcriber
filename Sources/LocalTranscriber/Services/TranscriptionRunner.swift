import Foundation

struct TranscriptionRunner: Sendable {
    func transcribe(
        audioFile: URL,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try self.ensureAudioFileExists(audioFile)
            return try self.runMLXWhisper(audioFile: audioFile, language: language, status: status)
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

    private func runMLXWhisper(
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
        let execution = try runProcess(tool: "mlx_whisper", arguments: arguments)

        guard execution.code == 0 else {
            throw TranscriptionError.processFailed(
                tool: "mlx_whisper",
                code: execution.code,
                output: displayTail(execution.output)
            )
        }

        status("Leser transkripsjonsfiler")
        let textURL = outputDirectory.appendingPathComponent("transcript.txt")
        let srtURL = outputDirectory.appendingPathComponent("transcript.srt")
        let jsonURL = outputDirectory.appendingPathComponent("transcript.json")

        guard FileManager.default.fileExists(atPath: textURL.path) else {
            throw TranscriptionError.missingOutput("MLX Whisper fullførte, men laget ikke transcript.txt.")
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

    private func ensureAudioFileExists(_ audioFile: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: audioFile.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else {
            throw TranscriptionError.fileNotFound(audioFile.path)
        }
    }

    private func runProcess(tool: String, arguments: [String]) throws -> (code: Int32, output: String) {
        let stdout = PipeCapture()
        let stderr = PipeCapture()
        let readers = DispatchGroup()
        stdout.start(in: readers)
        stderr.start(in: readers)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["HF_HUB_OFFLINE"] = "1"
        environment["TRANSFORMERS_OFFLINE"] = "1"
        environment["HF_HUB_DISABLE_TELEMETRY"] = "1"
        process.environment = environment
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe

        try process.run()
        process.waitUntilExit()
        readers.wait()

        let output = [stdout.string, stderr.string]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return (process.terminationStatus, output)
    }

    private func displayTail(_ text: String, maxCharacters: Int = 1_200) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return trimmed }
        return String(trimmed.suffix(maxCharacters))
    }
}

private enum TranscriptionError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case processFailed(tool: String, code: Int32, output: String)
    case missingOutput(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "Fant ikke lydfilen: \(path)"
        case .processFailed(let tool, let code, let output):
            "\(tool) feilet med kode \(code). \(output)"
        case .missingOutput(let message):
            message
        }
    }
}

private final class PipeCapture: @unchecked Sendable {
    let pipe = Pipe()

    private let lock = NSLock()
    private var data = Data()

    func start(in group: DispatchGroup) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            let captured = (try? self.pipe.fileHandleForReading.readToEnd()) ?? Data()
            self.lock.withLock {
                self.data = captured
            }
        }
    }

    var string: String {
        lock.withLock {
            String(decoding: data, as: UTF8.self)
        }
    }
}
