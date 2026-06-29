import Foundation

enum TranscriptionModel: Hashable, Identifiable, Sendable {
    case mlxLargeV3Turbo
    case hfLargeV3Turbo
    case hfLargeV3
    case canary1BV2
    case custom(id: String)

    static let availableBuiltIns: [TranscriptionModel] = [
        .mlxLargeV3Turbo,
        .hfLargeV3Turbo,
        .hfLargeV3,
        .canary1BV2
    ]
    static let defaultModels: [TranscriptionModel] = [.mlxLargeV3Turbo]

    var id: String {
        switch self {
        case .mlxLargeV3Turbo:
            "mlx-community/whisper-large-v3-turbo"
        case .hfLargeV3Turbo:
            "openai/whisper-large-v3-turbo"
        case .hfLargeV3:
            "openai/whisper-large-v3"
        case .canary1BV2:
            "nvidia/canary-1b-v2"
        case .custom(let id):
            id
        }
    }

    var displayName: String {
        switch self {
        case .mlxLargeV3Turbo:
            "Whisper large-v3-turbo (MLX, anbefalt)"
        case .hfLargeV3Turbo:
            "Whisper large-v3-turbo (Transformers/HF)"
        case .hfLargeV3:
            "Whisper large-v3 (Transformers/HF)"
        case .canary1BV2:
            "NVIDIA Canary 1B v2"
        case .custom(let id):
            id
        }
    }

    var detail: String {
        switch self {
        case .mlxLargeV3Turbo:
            "\(id) · anbefalt for norsk"
        case .hfLargeV3Turbo, .hfLargeV3:
            "\(id) · lokalt via Transformers/HF"
        case .canary1BV2:
            "\(id) · lokalt, ikke anbefalt for norsk"
        case .custom:
            "Egendefinert MLX modell-ID eller lokal mappe"
        }
    }

    var hasWarningDetail: Bool {
        switch self {
        case .canary1BV2:
            true
        case .mlxLargeV3Turbo, .hfLargeV3Turbo, .hfLargeV3, .custom:
            false
        }
    }

    static func models(from customModelText: String, includeDefault: Bool = true) -> [TranscriptionModel] {
        var models = includeDefault ? defaultModels : []
        let customModels = customModelText
            .split { $0 == "," || $0.isNewline }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { TranscriptionModel.custom(id: $0) }

        models.append(contentsOf: customModels)
        return unique(models)
    }

    static func unique(_ models: [TranscriptionModel]) -> [TranscriptionModel] {
        var seenIDs = Set<String>()
        var uniqueModels: [TranscriptionModel] = []

        for model in models where seenIDs.insert(model.id).inserted {
            uniqueModels.append(model)
        }

        return uniqueModels
    }
}

struct ModelTranscriptionResult: Identifiable, Sendable {
    let model: TranscriptionModel
    let result: TranscriptionResult

    var id: String { model.id }
}

struct MultiModelTranscriptionResult: Sendable {
    let results: [ModelTranscriptionResult]

    var comparisonText: String {
        guard !results.isEmpty else { return "" }

        var sections: [String] = []
        if results.count > 1 {
            let normalizedTexts = Set(results.map { normalize($0.result.text) })
            sections.append(normalizedTexts.count == 1
                ? "Alle valgte modeller ga samme normaliserte tekst."
                : "Modellene ga ulike tekster.")
        }

        for result in results {
            sections.append("""
            ## \(result.model.displayName)
            \(result.model.id)

            \(result.result.text)
            """)
        }

        return sections.joined(separator: "\n\n")
    }

    func result(for id: String) -> ModelTranscriptionResult? {
        results.first { $0.id == id }
    }

    private func normalize(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
