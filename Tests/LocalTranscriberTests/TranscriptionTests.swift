import Foundation
import Testing
@testable import LocalTranscriber

@Test func mlxWhisperArgumentsUseNorwegianAndAllOutputs() {
    let outputDirectory = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
    let arguments = TranscriptionRunner.mlxWhisperArguments(
        audioFile: URL(fileURLWithPath: "/tmp/test.wav"),
        language: .norwegian,
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

@Test func languagesExposeOneSharedOptionalCliCode() {
    #expect(TranscriptionLanguage.norwegian.cliCode == "no")
    #expect(TranscriptionLanguage.english.cliCode == "en")
    #expect(TranscriptionLanguage.swedish.cliCode == "sv")
    #expect(TranscriptionLanguage.danish.cliCode == "da")
    #expect(TranscriptionLanguage.auto.cliCode == nil)
}
