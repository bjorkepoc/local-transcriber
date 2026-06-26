import Foundation

public struct TranscriptionRunner: Sendable {
    private let resolver: ToolResolver

    public init(resolver: ToolResolver = ToolResolver()) {
        self.resolver = resolver
    }

    public func transcribe(
        _ request: TranscriptionRequest,
        status: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try self.transcribeSynchronously(request, status: status)
        }.value
    }

    static func mlxWhisperArguments(
        request: TranscriptionRequest,
        outputDirectory: URL,
        outputName: String = "transcript"
    ) -> [String] {
        var arguments = [
            "--model", "mlx-community/whisper-large-v3-turbo",
            "--output-format", "all",
            "--output-dir", outputDirectory.path,
            "--output-name", outputName
        ]

        if let languageCode = request.language.whisperCode {
            arguments.append(contentsOf: ["--language", languageCode])
        }

        arguments.append(request.audioFile.path)
        return arguments
    }

    static func canaryArguments(request: TranscriptionRequest) -> [String] {
        var arguments: [String] = []

        if let sourceLanguage = request.language.canaryCode {
            arguments.append(contentsOf: ["--source-lang", sourceLanguage])
        }

        arguments.append(request.audioFile.path)
        return arguments
    }

    private func transcribeSynchronously(
        _ request: TranscriptionRequest,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        guard request.model.isRunnable else {
            throw TranscriptionError.unsupportedModel(request.model.unavailableReason)
        }

        try ensureAudioFileExists(request.audioFile)

        status("Sjekker lokale verktøy")
        let ffmpegURL = try requireTool("ffmpeg")
        try ensureModelIsCached(request.model)

        status("Validerer lydfil med ffmpeg")
        try validateAudioFile(ffmpegURL: ffmpegURL, audioFile: request.audioFile)

        switch request.model.runnerKind {
        case .mlxWhisper:
            return try runMLXWhisper(request: request, status: status)
        case .canary:
            return try runCanary(request: request, status: status)
        case .unavailable:
            throw TranscriptionError.unsupportedModel(request.model.unavailableReason)
        }
    }

    private func runMLXWhisper(
        request: TranscriptionRequest,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        let mlxWhisperURL = try requireTool("mlx_whisper")
        let outputDirectory = try createTemporaryDirectory(named: "mlx-output")
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        status("Kjører MLX Whisper lokalt")
        let arguments = Self.mlxWhisperArguments(request: request, outputDirectory: outputDirectory)
        let execution = try runProcess(executableURL: mlxWhisperURL, arguments: arguments)

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

        var outputs: [TranscriptOutputFormat: String] = [
            .txt: try String(contentsOf: textURL, encoding: .utf8)
        ]

        if FileManager.default.fileExists(atPath: srtURL.path) {
            outputs[.srt] = try String(contentsOf: srtURL, encoding: .utf8)
        }

        if FileManager.default.fileExists(atPath: jsonURL.path) {
            outputs[.json] = try String(contentsOf: jsonURL, encoding: .utf8)
        }

        return TranscriptionResult(
            text: outputs[.txt]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            outputs: outputs
        )
    }

    private func runCanary(
        request: TranscriptionRequest,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        let canaryURL = try requireTool("canary-transcribe")

        status("Kjører NVIDIA Canary lokalt")
        let arguments = Self.canaryArguments(request: request)
        let execution = try runProcess(executableURL: canaryURL, arguments: arguments)

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

        return TranscriptionResult(
            text: text,
            outputs: [.txt: text]
        )
    }

    private func validateAudioFile(ffmpegURL: URL, audioFile: URL) throws {
        let execution = try runProcess(
            executableURL: ffmpegURL,
            arguments: ["-v", "error", "-i", audioFile.path, "-t", "0.1", "-f", "null", "-"]
        )

        guard execution.terminationStatus == 0 else {
            throw TranscriptionError.invalidAudioFile(displayTail(execution.combinedOutput))
        }
    }

    private func ensureAudioFileExists(_ audioFile: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: audioFile.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else {
            throw TranscriptionError.fileNotFound(audioFile.path)
        }
    }

    private func ensureModelIsCached(_ model: TranscriptionModel) throws {
        guard let repositoryID = model.repositoryID else { return }
        let cacheDirectory = huggingFaceHubCacheDirectory()
        let expectedDirectory = cacheDirectory.appendingPathComponent(
            "models--\(repositoryID.replacingOccurrences(of: "/", with: "--"))",
            isDirectory: true
        )

        guard FileManager.default.fileExists(atPath: expectedDirectory.path) else {
            throw TranscriptionError.missingModel(
                repositoryID: repositoryID,
                expectedPath: expectedDirectory.path
            )
        }
    }

    private func requireTool(_ name: String) throws -> URL {
        guard let url = resolver.resolve(name) else {
            throw TranscriptionError.missingTool(name: name, searchedPaths: resolver.searchPaths)
        }
        return url
    }

    private func runProcess(executableURL: URL, arguments: [String]) throws -> ProcessExecution {
        let runDirectory = try createTemporaryDirectory(named: "process")
        defer { try? FileManager.default.removeItem(at: runDirectory) }

        let stdoutURL = runDirectory.appendingPathComponent("stdout.log")
        let stderrURL = runDirectory.appendingPathComponent("stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = processEnvironment()
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        try process.run()
        process.waitUntilExit()

        let standardOutput = try String(contentsOf: stdoutURL, encoding: .utf8)
        let standardError = try String(contentsOf: stderrURL, encoding: .utf8)

        return ProcessExecution(
            terminationStatus: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = resolver.searchPaths.joined(separator: ":")
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

    private func huggingFaceHubCacheDirectory() -> URL {
        let environment = ProcessInfo.processInfo.environment

        if let hubCache = environment["HF_HUB_CACHE"], !hubCache.isEmpty {
            return URL(fileURLWithPath: hubCache, isDirectory: true)
        }

        if let hfHome = environment["HF_HOME"], !hfHome.isEmpty {
            return URL(fileURLWithPath: hfHome, isDirectory: true)
                .appendingPathComponent("hub", isDirectory: true)
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".cache/huggingface/hub", isDirectory: true)
    }

    private func displayTail(_ text: String, maxCharacters: Int = 1_200) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return trimmed }
        return String(trimmed.suffix(maxCharacters))
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
