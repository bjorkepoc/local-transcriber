import Foundation

struct TranscriptionRunner: Sendable {
    func transcribe(
        audioFile: URL,
        model: TranscriptionModel,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try self.transcribeSynchronously(
                audioFile: audioFile,
                model: model,
                language: language,
                status: status
            )
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

    static func canaryArguments(audioFile: URL, language: TranscriptionLanguage) -> [String] {
        var arguments: [String] = []

        if let sourceLanguage = language.cliCode {
            arguments.append(contentsOf: ["--source-lang", sourceLanguage])
        }

        arguments.append(audioFile.path)
        return arguments
    }

    private func transcribeSynchronously(
        audioFile: URL,
        model: TranscriptionModel,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        try ensureAudioFileExists(audioFile)

        switch model {
        case .mlxWhisperLargeV3Turbo:
            return try runMLXWhisper(audioFile: audioFile, language: language, status: status)
        case .canary1BV2:
            return try runCanary(audioFile: audioFile, language: language, status: status)
        }
    }

    private func runMLXWhisper(
        audioFile: URL,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        let outputDirectory = try createTemporaryDirectory(named: "mlx-output")
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        status("Kjører MLX Whisper lokalt")
        let arguments = Self.mlxWhisperArguments(
            audioFile: audioFile,
            language: language,
            outputDirectory: outputDirectory
        )
        let execution = try runProcess(tool: "mlx_whisper", arguments: arguments)

        guard execution.terminationStatus == 0 else {
            throw TranscriptionError.processFailed(
                tool: "mlx_whisper",
                code: execution.terminationStatus,
                output: displayTail(execution.combinedOutput)
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

    private func runCanary(
        audioFile: URL,
        language: TranscriptionLanguage,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        status("Kjører NVIDIA Canary lokalt")
        let arguments = Self.canaryArguments(audioFile: audioFile, language: language)
        let execution = try runProcess(tool: "canary-transcribe", arguments: arguments)

        guard execution.terminationStatus == 0 else {
            throw TranscriptionError.processFailed(
                tool: "canary-transcribe",
                code: execution.terminationStatus,
                output: displayTail(execution.combinedOutput)
            )
        }

        let text = execution.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.missingOutput("Canary fullførte, men ga ingen transkripsjon på stdout.")
        }

        return TranscriptionResult(text: text, srt: nil, json: nil)
    }

    private func ensureAudioFileExists(_ audioFile: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: audioFile.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else {
            throw TranscriptionError.fileNotFound(audioFile.path)
        }
    }

    private func runProcess(tool: String, arguments: [String]) throws -> ProcessExecution {
        let stdout = PipeCapture()
        let stderr = PipeCapture()
        let readers = DispatchGroup()
        stdout.start(in: readers)
        stderr.start(in: readers)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments
        process.environment = processEnvironment()
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe

        try process.run()
        process.waitUntilExit()
        readers.wait()

        return ProcessExecution(
            terminationStatus: process.terminationStatus,
            standardOutput: stdout.string,
            standardError: stderr.string
        )
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HF_HUB_OFFLINE"] = "1"
        environment["TRANSFORMERS_OFFLINE"] = "1"
        environment["HF_HUB_DISABLE_TELEMETRY"] = "1"
        return environment
    }

    private func createTemporaryDirectory(named prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalTranscriber-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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

private struct ProcessExecution: Sendable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String

    var combinedOutput: String {
        [standardOutput, standardError]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
