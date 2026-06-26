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

    #expect(arguments.contains("--model"))
    #expect(arguments.contains("mlx-community/whisper-large-v3-turbo"))
    #expect(arguments.contains("--language"))
    #expect(arguments.contains("no"))
    #expect(arguments.contains("--output-format"))
    #expect(arguments.contains("all"))
    #expect(arguments.contains("--output-name"))
    #expect(arguments.contains("transcript"))
    #expect(arguments.last == "/tmp/test.wav")
}

@Test func languagesExposeOneSharedOptionalCliCode() {
    #expect(TranscriptionLanguage.norwegian.cliCode == "no")
    #expect(TranscriptionLanguage.english.cliCode == "en")
    #expect(TranscriptionLanguage.swedish.cliCode == "sv")
    #expect(TranscriptionLanguage.danish.cliCode == "da")
    #expect(TranscriptionLanguage.auto.cliCode == nil)
}
