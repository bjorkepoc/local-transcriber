import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var audioFile: URL?
    @Published var selectedLanguage: TranscriptionLanguage = .norwegian
    @Published var transcript = ""
    @Published var statusText = "Klar"
    @Published var errorMessage: String?
    @Published var isRunning = false

    private let runner = TranscriptionRunner()
    private var lastResult: TranscriptionResult?

    var canStart: Bool {
        audioFile != nil && !isRunning
    }

    var selectedFileName: String {
        audioFile?.lastPathComponent ?? "Ingen lydfil valgt"
    }

    var selectedFilePath: String {
        audioFile?.path ?? ""
    }

    var canSaveText: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func chooseAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .movie]

        if panel.runModal() == .OK {
            audioFile = panel.url
            errorMessage = nil
            statusText = "Klar"
        }
    }

    func transcribe() async {
        guard let audioFile else {
            errorMessage = "Velg en lydfil først."
            return
        }

        isRunning = true
        errorMessage = nil
        lastResult = nil
        statusText = "Starter lokal transkribering"

        do {
            let result = try await runner.transcribe(
                audioFile: audioFile,
                language: selectedLanguage
            ) { [weak self] message in
                Task { @MainActor in
                    self?.statusText = message
                }
            }

            transcript = result.text
            lastResult = result
            statusText = "Ferdig"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusText = "Feilet"
        }

        isRunning = false
    }

    func copyTranscript() {
        guard canSaveText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        statusText = "Kopiert"
    }

    func saveTranscriptAsText() {
        save(
            contents: transcript,
            defaultName: defaultOutputName(extension: "txt"),
            allowedTypes: [.plainText]
        )
    }

    var canSaveSRT: Bool {
        lastResult?.srt != nil
    }

    var canSaveJSON: Bool {
        lastResult?.json != nil
    }

    func saveGeneratedSRT() {
        saveGenerated(contents: lastResult?.srt, extension: "srt", contentType: UTType(filenameExtension: "srt") ?? .plainText)
    }

    func saveGeneratedJSON() {
        saveGenerated(contents: lastResult?.json, extension: "json", contentType: .json)
    }

    private func save(contents: String, defaultName: String, allowedTypes: [UTType]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = allowedTypes
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            statusText = "Lagret \(url.lastPathComponent)"
        } catch {
            errorMessage = "Kunne ikke lagre filen: \(error.localizedDescription)"
        }
    }

    private func defaultOutputName(extension fileExtension: String) -> String {
        let base = audioFile?.deletingPathExtension().lastPathComponent ?? "transkripsjon"
        return "\(base).\(fileExtension)"
    }

    private func saveGenerated(contents: String?, extension fileExtension: String, contentType: UTType) {
        guard let contents else { return }
        save(
            contents: contents,
            defaultName: defaultOutputName(extension: fileExtension),
            allowedTypes: [contentType]
        )
    }
}
