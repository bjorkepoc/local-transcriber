import Foundation
import Testing
@testable import LocalTranscriberCore

@Test func mlxWhisperArgumentsUseNorwegianAndAllOutputs() {
    let request = TranscriptionRequest(
        audioFile: URL(fileURLWithPath: "/tmp/test.wav"),
        model: .mlxWhisperLargeV3Turbo,
        language: .norwegian
    )

    let outputDirectory = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
    let arguments = TranscriptionRunner.mlxWhisperArguments(
        request: request,
        outputDirectory: outputDirectory
    )

    #expect(arguments.contains("--model"))
    #expect(arguments.contains("mlx-community/whisper-large-v3-turbo"))
    #expect(arguments.contains("--language"))
    #expect(arguments.contains("no"))
    #expect(arguments.contains("--output-format"))
    #expect(arguments.contains("all"))
    #expect(arguments.last == "/tmp/test.wav")
}

@Test func hfModelsAreVisibleButNotRunnableInVersionOne() {
    #expect(TranscriptionModel.hfWhisperLargeV3Turbo.isRunnable == false)
    #expect(TranscriptionModel.hfWhisperLargeV3.isRunnable == false)
    #expect(TranscriptionModel.hfWhisperLargeV3Turbo.defaultLanguage == .norwegian)
}

@Test func canaryIsRunnableButWarnedForNorwegianUse() {
    #expect(TranscriptionModel.canary1BV2.isRunnable)
    #expect(TranscriptionModel.canary1BV2.notice == "Ikke anbefalt for norsk")

    let request = TranscriptionRequest(
        audioFile: URL(fileURLWithPath: "/tmp/test.wav"),
        model: .canary1BV2,
        language: .norwegian
    )

    let arguments = TranscriptionRunner.canaryArguments(request: request)
    #expect(arguments == ["--source-lang", "no", "/tmp/test.wav"])
}
