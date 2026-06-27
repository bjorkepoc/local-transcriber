import Foundation

extension TranscriptionRunner {
    static func transcribe(
        audioFile: URL,
        language: TranscriptionLanguage,
        models: [TranscriptionModel],
        status: @escaping @Sendable (String) -> Void
    ) async throws -> MultiModelTranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try ensureMultiModelAudioFileExists(audioFile)

            let uniqueModels = TranscriptionModel.unique(models)
            guard !uniqueModels.isEmpty else {
                throw MultiModelTranscriptionError.noModelsSelected
            }

            status(uniqueModels.count == 1
                ? "Kjører \(uniqueModels[0].displayName)"
                : "Kjører \(uniqueModels.count) modeller lokalt")

            return try await runModels(
                audioFile: audioFile,
                language: language,
                models: uniqueModels,
                status: status
            )
        }.value
    }

    static func mlxWhisperArguments(
        audioFile: URL,
        language: TranscriptionLanguage,
        model: TranscriptionModel,
        outputDirectory: URL
    ) -> [String] {
        var arguments = [
            "--model", model.id,
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

    private static func runModels(
        audioFile: URL,
        language: TranscriptionLanguage,
        models: [TranscriptionModel],
        status: @escaping @Sendable (String) -> Void
    ) async throws -> MultiModelTranscriptionResult {
        var resultsByID: [String: ModelTranscriptionResult] = [:]

        try await withThrowingTaskGroup(of: ModelTranscriptionResult.self) { group in
            for model in models {
                group.addTask {
                    let result: TranscriptionResult

                    switch model {
                    case .mlxLargeV3Turbo, .custom:
                        result = try runMLXWhisper(
                            audioFile: audioFile,
                            language: language,
                            model: model,
                            status: status
                        )
                    case .canary1BV2:
                        result = try runCanary(
                            audioFile: audioFile,
                            language: language,
                            model: model,
                            status: status
                        )
                    case .hfLargeV3Turbo, .hfLargeV3:
                        throw MultiModelTranscriptionError.unsupportedModel(modelID: model.id)
                    }

                    return ModelTranscriptionResult(model: model, result: result)
                }
            }

            for try await result in group {
                resultsByID[result.id] = result
            }
        }

        return MultiModelTranscriptionResult(results: models.compactMap { resultsByID[$0.id] })
    }

    private static func runMLXWhisper(
        audioFile: URL,
        language: TranscriptionLanguage,
        model: TranscriptionModel,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalTranscriber-mlx-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        status("Kjører \(model.displayName)")
        let arguments = Self.mlxWhisperArguments(
            audioFile: audioFile,
            language: language,
            model: model,
            outputDirectory: outputDirectory
        )
        let execution = try runMultiModelProcess(command: "mlx_whisper", arguments: arguments)

        guard execution.code == 0 else {
            let output = execution.output.count > 1_200
                ? String(execution.output.suffix(1_200))
                : execution.output
            throw MultiModelTranscriptionError.processFailed(
                modelID: model.id,
                code: execution.code,
                output: output
            )
        }

        status("Leser transkripsjonsfiler")
        let textURL = outputDirectory.appendingPathComponent("transcript.txt")
        let srtURL = outputDirectory.appendingPathComponent("transcript.srt")
        let jsonURL = outputDirectory.appendingPathComponent("transcript.json")

        guard FileManager.default.fileExists(atPath: textURL.path) else {
            throw MultiModelTranscriptionError.missingOutput
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

    static func canaryArguments(audioFile: URL, language: TranscriptionLanguage) -> [String] {
        var arguments: [String] = []

        if let sourceLanguage = language.cliCode {
            arguments.append(contentsOf: ["--source-lang", sourceLanguage])
        }

        arguments.append(audioFile.path)
        return arguments
    }

    private static func runCanary(
        audioFile: URL,
        language: TranscriptionLanguage,
        model: TranscriptionModel,
        status: @escaping @Sendable (String) -> Void
    ) throws -> TranscriptionResult {
        status("Kjører \(model.displayName)")
        let arguments = canaryArguments(audioFile: audioFile, language: language)
        let execution = try runMultiModelProcess(command: "canary-transcribe", arguments: arguments)

        guard execution.code == 0 else {
            let output = execution.output.count > 1_200
                ? String(execution.output.suffix(1_200))
                : execution.output
            throw MultiModelTranscriptionError.processFailed(
                modelID: model.id,
                code: execution.code,
                output: output
            )
        }

        return TranscriptionResult(
            text: execution.output.trimmingCharacters(in: .whitespacesAndNewlines),
            srt: nil,
            json: nil
        )
    }

    private static func ensureMultiModelAudioFileExists(_ audioFile: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: audioFile.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else {
            throw MultiModelTranscriptionError.fileNotFound(audioFile.path)
        }
    }

    private static func runMultiModelProcess(command: String, arguments: [String]) throws -> (code: Int32, output: String) {
        let outputPipe = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
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

private enum MultiModelTranscriptionError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case noModelsSelected
    case processFailed(modelID: String, code: Int32, output: String)
    case missingOutput
    case unsupportedModel(modelID: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "Fant ikke lydfilen: \(path)"
        case .noModelsSelected:
            "Velg minst én modell."
        case .processFailed(let modelID, let code, let output):
            "mlx_whisper feilet for \(modelID) med kode \(code). \(output)"
        case .missingOutput:
            "MLX Whisper fullførte, men laget ikke transcript.txt."
        case .unsupportedModel(let modelID):
            "\(modelID) er lastet ned lokalt, men appen har ikke en lokal runner for denne modelltypen ennå."
        }
    }
}
