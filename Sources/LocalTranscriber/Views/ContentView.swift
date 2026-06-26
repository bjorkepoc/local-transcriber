import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()

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
                    Label("Transkriber", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.audioFile == nil || viewModel.isRunning)

                if viewModel.isRunning {
                    ProgressView()
                }

                Text(viewModel.statusText)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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

            Spacer()

            Button {
                viewModel.copyTranscript()
            } label: {
                Label("Kopier tekst", systemImage: "doc.on.doc")
            }
            .disabled(!viewModel.canSaveText)

            Button {
                viewModel.saveTranscriptAsText()
            } label: {
                Label("Lagre TXT", systemImage: "square.and.arrow.down")
            }
            .disabled(!viewModel.canSaveText)

            Button {
                viewModel.saveGeneratedSRT()
            } label: {
                Label("Lagre SRT", systemImage: "captions.bubble")
            }
            .disabled(!viewModel.canSaveSRT)

            Button {
                viewModel.saveGeneratedJSON()
            } label: {
                Label("Lagre JSON", systemImage: "curlybraces")
            }
            .disabled(!viewModel.canSaveJSON)
        }
    }
}
