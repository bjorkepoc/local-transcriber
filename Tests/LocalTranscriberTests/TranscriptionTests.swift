import Foundation
import Testing
@testable import LocalTranscriber

@Test func mlxWhisperArgumentsUseNorwegianAndAllOutputs() {
    let outputDirectory = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
    let arguments = TranscriptionRunner.mlxWhisperArguments(
        audioFile: URL(fileURLWithPath: "/tmp/test.wav"),
        language: .norwegian,
        model: .mlxLargeV3Turbo,
        outputDirectory: outputDirectory
    )

    #expect(arguments == [
        "--model", "mlx-community/whisper-large-v3-turbo",
        "--output-format", "all",
        "--output-dir", "/tmp/out",
        "--output-name", "transcript",
        "--language", "no",
        "/tmp/test.wav"
    ])
}

@Test func mlxWhisperArgumentsUseSelectedModelID() {
    let outputDirectory = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
    let model = TranscriptionModel.custom(id: "local-models/meeting-whisper")
    let arguments = TranscriptionRunner.mlxWhisperArguments(
        audioFile: URL(fileURLWithPath: "/tmp/test.wav"),
        language: .auto,
        model: model,
        outputDirectory: outputDirectory
    )

    #expect(arguments == [
        "--model", "local-models/meeting-whisper",
        "--output-format", "all",
        "--output-dir", "/tmp/out",
        "--output-name", "transcript",
        "/tmp/test.wav"
    ])
}

@Test func transcriptionModelsNormalizeCustomInput() {
    #expect(TranscriptionModel.models(from: " one \n\ntwo, three ").map(\.id) == [
        "mlx-community/whisper-large-v3-turbo",
        "one",
        "two",
        "three"
    ])
}

@Test func builtInModelsIncludeDownloadedLocalModels() {
    #expect(TranscriptionModel.availableBuiltIns.map(\.id) == [
        "mlx-community/whisper-large-v3-turbo",
        "openai/whisper-large-v3-turbo",
        "openai/whisper-large-v3",
        "nvidia/canary-1b-v2"
    ])
    #expect(TranscriptionModel.hfLargeV3Turbo.isRunnable == false)
    #expect(TranscriptionModel.hfLargeV3.isRunnable == false)
    #expect(TranscriptionModel.canary1BV2.isRunnable)
}

@Test func canaryArgumentsUseSelectedLanguage() {
    let arguments = TranscriptionRunner.canaryArguments(
        audioFile: URL(fileURLWithPath: "/tmp/test.wav"),
        language: .english
    )

    #expect(arguments == [
        "--source-lang", "en",
        "/tmp/test.wav"
    ])
}

@Test func multiModelComparisonShowsEachResult() {
    let output = MultiModelTranscriptionResult(results: [
        ModelTranscriptionResult(model: .mlxLargeV3Turbo, result: TranscriptionResult(text: "Hei verden", srt: "1", json: "{}")),
        ModelTranscriptionResult(model: .canary1BV2, result: TranscriptionResult(text: "Hei, verden", srt: nil, json: nil))
    ])

    #expect(output.comparisonText.contains("Whisper large-v3-turbo (MLX, anbefalt)"))
    #expect(output.comparisonText.contains("NVIDIA Canary 1B v2"))
    #expect(output.comparisonText.contains("Hei verden"))
    #expect(output.comparisonText.contains("Hei, verden"))
}

@Test func languagesExposeOneSharedOptionalCliCode() {
    #expect(TranscriptionLanguage.norwegian.cliCode == "no")
    #expect(TranscriptionLanguage.english.cliCode == "en")
    #expect(TranscriptionLanguage.swedish.cliCode == "sv")
    #expect(TranscriptionLanguage.danish.cliCode == "da")
    #expect(TranscriptionLanguage.auto.cliCode == nil)
}
