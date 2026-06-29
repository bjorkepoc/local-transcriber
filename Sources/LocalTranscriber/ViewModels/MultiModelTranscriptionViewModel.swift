import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

struct TranscriptOutputChoice: Identifiable {
    let id: String
    let displayName: String
}

@MainActor
final class MultiModelTranscriptionViewModel: ObservableObject {
    static let comparisonOutputID = "__local-transcriber-comparison__"

    @Published var audioFile: URL?
    @Published var selectedLanguage: TranscriptionLanguage = .norwegian
    @Published var selectedBuiltInModels = Set(TranscriptionModel.defaultModels)
    @Published var customModelText = ""
    @Published var transcript = ""
    @Published var statusText = "Klar"
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published private(set) var modelResults: [ModelTranscriptionResult] = []
    @Published private(set) var selectedOutputID = MultiModelTranscriptionViewModel.comparisonOutputID

    private var editedTextByOutputID: [String: String] = [:]

    var selectedModels: [TranscriptionModel] {
        let builtIns = TranscriptionModel.availableBuiltIns.filter {
            selectedBuiltInModels.contains($0)
        }
        let customModels = TranscriptionModel.models(from: customModelText, includeDefault: false)
        return TranscriptionModel.unique(builtIns + customModels)
    }

    var selectedModelCount: Int { selectedModels.count }
    var canStart: Bool { audioFile != nil && !isRunning && !selectedModels.isEmpty }
    var canSaveText: Bool { !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var outputChoices: [TranscriptOutputChoice] {
        guard !modelResults.isEmpty else { return [] }

        var choices: [TranscriptOutputChoice] = []
        if modelResults.count > 1 {
            choices.append(TranscriptOutputChoice(id: Self.comparisonOutputID, displayName: "Sammenligning"))
        }

        choices.append(contentsOf: modelResults.map {
            TranscriptOutputChoice(id: $0.id, displayName: $0.model.displayName)
        })

        return choices
    }

    var hasOutputChoices: Bool { outputChoices.count > 1 }

    private var selectedModelResult: ModelTranscriptionResult? {
        modelResults.first { $0.id == selectedOutputID }
    }

    func chooseAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .movie]

        if panel.runModal() == .OK {
            audioFile = panel.url
            errorMessage = nil
            statusText = "Klar"
            clearResults()
        }
    }

    func isBuiltInModelSelected(_ model: TranscriptionModel) -> Bool {
        selectedBuiltInModels.contains(model)
    }

    func setBuiltInModel(_ model: TranscriptionModel, isSelected: Bool) {
        if isSelected {
            selectedBuiltInModels.insert(model)
        } else {
            selectedBuiltInModels.remove(model)
        }
    }

    func selectOutput(_ outputID: String) {
        guard selectedOutputID != outputID else { return }
        editedTextByOutputID[selectedOutputID] = transcript
        selectedOutputID = outputID
        transcript = editedTextByOutputID[outputID] ?? ""
    }

    func transcribe() async {
        guard let audioFile else {
            errorMessage = "Velg en lydfil først."
            return
        }

        let models = selectedModels
        guard !models.isEmpty else {
            errorMessage = "Velg minst én modell."
            return
        }

        isRunning = true
        errorMessage = nil
        clearResults()
        statusText = "Starter lokal transkribering"

        do {
            let result = try await TranscriptionRunner.transcribe(
                audioFile: audioFile,
                language: selectedLanguage,
                models: models
            ) { [weak self] message in
                Task { @MainActor in
                    self?.statusText = message
                }
            }

            apply(result)
            statusText = result.results.count == 1
                ? "Ferdig med 1 modell"
                : "Ferdig med \(result.results.count) modeller"
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
        save(contents: transcript, defaultName: defaultOutputName(extension: "txt"), allowedTypes: [.plainText])
    }

    var canSaveSRT: Bool { selectedModelResult?.result.srt != nil }
    var canSaveJSON: Bool { selectedModelResult?.result.json != nil }

    func saveGeneratedSRT() {
        saveGenerated(contents: selectedModelResult?.result.srt, extension: "srt", contentType: UTType(filenameExtension: "srt") ?? .plainText)
    }

    func saveGeneratedJSON() {
        saveGenerated(contents: selectedModelResult?.result.json, extension: "json", contentType: .json)
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
        guard let suffix = selectedOutputSuffix else {
            return "\(base).\(fileExtension)"
        }

        return "\(base)-\(suffix).\(fileExtension)"
    }

    private var selectedOutputSuffix: String? {
        if selectedOutputID == Self.comparisonOutputID {
            return modelResults.count > 1 ? "sammenligning" : nil
        }

        guard modelResults.count > 1, let selectedModelResult else {
            return nil
        }

        let allowedCharacters = CharacterSet.alphanumerics
        let suffixCharacters = selectedModelResult.model.id.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        }
        return String(suffixCharacters)
    }

    private func saveGenerated(contents: String?, extension fileExtension: String, contentType: UTType) {
        guard let contents else { return }
        save(contents: contents, defaultName: defaultOutputName(extension: fileExtension), allowedTypes: [contentType])
    }

    private func apply(_ result: MultiModelTranscriptionResult) {
        modelResults = result.results
        editedTextByOutputID = [:]

        if result.results.count > 1 {
            editedTextByOutputID[Self.comparisonOutputID] = result.comparisonText
        }

        for modelResult in result.results {
            editedTextByOutputID[modelResult.id] = modelResult.result.text
        }

        selectedOutputID = result.results.count > 1
            ? Self.comparisonOutputID
            : result.results.first?.id ?? Self.comparisonOutputID
        transcript = editedTextByOutputID[selectedOutputID] ?? ""
    }

    private func clearResults() {
        transcript = ""
        modelResults = []
        selectedOutputID = Self.comparisonOutputID
        editedTextByOutputID = [:]
    }
}
