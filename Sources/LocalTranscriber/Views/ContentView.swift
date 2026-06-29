import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MultiModelTranscriptionViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 430)
        } detail: {
            transcriptPane
        }
    }

    private var sidebar: some View {
        Form {
            Section("Lydfil") {
                VStack(alignment: .leading, spacing: 6) {
                    Label(viewModel.audioFile?.lastPathComponent ?? "Ingen lydfil valgt", systemImage: "waveform")
                        .lineLimit(2)

                    if let audioFile = viewModel.audioFile {
                        Text(audioFile.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }

                Button {
                    viewModel.chooseAudioFile()
                } label: {
                    Label("Velg lydfil", systemImage: "folder")
                }
            }

            Section("Språk") {
                Picker("Språk", selection: $viewModel.selectedLanguage) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.transcribe()
                    }
                } label: {
                    Label(viewModel.selectedModelCount > 1 ? "Transkriber modeller" : "Transkriber", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStart)

                if viewModel.isRunning {
                    ProgressView()
                }

                Text(viewModel.statusText)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("Modeller") {
                ForEach(TranscriptionModel.availableBuiltIns, id: \.id) { model in
                    Toggle(isOn: Binding(
                        get: { viewModel.isBuiltInModelSelected(model) },
                        set: { viewModel.setBuiltInModel(model, isSelected: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                            Text(model.detail)
                                .font(.caption)
                                .foregroundStyle(model.hasWarningDetail ? Color.orange : Color.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                TextField("Ekstra MLX modell-ID-er", text: $viewModel.customModelText)
                    .textFieldStyle(.roundedBorder)

                Text("\(viewModel.selectedModelCount) valgt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section("Feil") {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var transcriptPane: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)

            Divider()

            TextEditor(text: $viewModel.transcript)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(14)
                .overlay {
                    if viewModel.transcript.isEmpty {
                        Text("Transkripsjonen vises her")
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("Transkripsjon")
                .font(.headline)

            if viewModel.hasOutputChoices {
                Picker("Vis", selection: Binding(
                    get: { viewModel.selectedOutputID },
                    set: { viewModel.selectOutput($0) }
                )) {
                    ForEach(viewModel.outputChoices) { choice in
                        Text(choice.displayName).tag(choice.id)
                    }
                }
                .frame(maxWidth: 260)
            }

            Spacer()

            Button {
                viewModel.copyTranscript()
            } label: {
                Label("Kopier", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help("Kopier tekst")
            .disabled(!viewModel.canSaveText)

            Button {
                viewModel.saveTranscriptAsText()
            } label: {
                Label("TXT", systemImage: "square.and.arrow.down")
            }
            .labelStyle(.iconOnly)
            .help("Lagre som TXT")
            .disabled(!viewModel.canSaveText)

            Button {
                viewModel.saveGeneratedSRT()
            } label: {
                Label("SRT", systemImage: "captions.bubble")
            }
            .labelStyle(.iconOnly)
            .help("Lagre som SRT")
            .disabled(!viewModel.canSaveSRT)

            Button {
                viewModel.saveGeneratedJSON()
            } label: {
                Label("JSON", systemImage: "curlybraces")
            }
            .labelStyle(.iconOnly)
            .help("Lagre som JSON")
            .disabled(!viewModel.canSaveJSON)
        }
    }
}
