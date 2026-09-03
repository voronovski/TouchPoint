import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct GreetingGenerationContext: Sendable {
    var occasion: String
    var relationship: String
    var channel: String
    var language: String
    var recipientName: String?
    var usesNamePlaceholder: Bool
}

enum AppleGreetingGeneratorStatus: Equatable {
    case available
    case unavailable(String)
}

enum AppleGreetingGeneratorError: LocalizedError {
    case unsupportedOS
    case modelUnavailable(String)
    case unsupportedLocale
    case emptyResponse
    case invalidPlaceholder

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            "Apple Intelligence generation requires iOS 26 or later."
        case .modelUnavailable(let reason):
            reason
        case .unsupportedLocale:
            "Apple Intelligence does not support the current device language. You can still write the message manually."
        case .emptyResponse:
            "Apple Intelligence returned an empty message. Please try again."
        case .invalidPlaceholder:
            "The generated message used an unsupported name placeholder. Please generate again or edit it manually."
        }
    }
}

enum AppleGreetingGenerator {
    @MainActor
    static var status: AppleGreetingGeneratorStatus {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            return .unavailable("Apple Intelligence generation requires iOS 26 or later.")
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(unavailableMessage(for: reason))
        }
#else
        return .unavailable("This build does not include Apple's Foundation Models framework.")
#endif
    }

    @MainActor
    static func generate(
        context: GreetingGenerationContext,
        tone: String,
        details: String
    ) async throws -> String {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw AppleGreetingGeneratorError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            if case .unavailable(let reason) = model.availability {
                throw AppleGreetingGeneratorError.modelUnavailable(unavailableMessage(for: reason))
            }
            throw AppleGreetingGeneratorError.modelUnavailable("Apple Intelligence is not available right now.")
        }
        guard model.supportsLocale(.current) else {
            throw AppleGreetingGeneratorError.unsupportedLocale
        }

        let session = LanguageModelSession(instructions: """
        You write thoughtful, natural greeting messages for a relationship reminder app.
        Return only the finished message body: no title, quotation marks, analysis, or alternatives.
        Never invent personal facts. Keep the message appropriate for the stated relationship and channel.
        """)

        let nameInstruction: String
        if context.usesNamePlaceholder {
            nameInstruction = "Use the literal placeholder {{first_name}} exactly once instead of a person's name."
        } else if let recipientName = context.recipientName, !recipientName.isEmpty {
            nameInstruction = "Address the recipient by the first name \(recipientName)."
        } else {
            nameInstruction = "Do not address the recipient by name."
        }

        let extraDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        Write one greeting with these constraints:
        Occasion: \(context.occasion)
        Relationship: \(context.relationship)
        Delivery channel: \(context.channel)
        Language: \(context.language)
        Tone: \(tone)
        \(nameInstruction)
        Additional direction: \(extraDetails.isEmpty ? "None" : extraDetails)
        Keep it concise enough for the delivery channel.
        """

        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AppleGreetingGeneratorError.emptyResponse }
        let placeholderCount = text.components(separatedBy: "{{first_name}}").count - 1
        if context.usesNamePlaceholder {
            guard placeholderCount == 1 else { throw AppleGreetingGeneratorError.invalidPlaceholder }
        } else if text.contains("{{") || text.contains("}}") {
            throw AppleGreetingGeneratorError.invalidPlaceholder
        }
        return text
#else
        throw AppleGreetingGeneratorError.unsupportedOS
#endif
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func unavailableMessage(
        for reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            "Apple Intelligence is not supported on this device. You can still write or edit the message manually."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to generate messages on device."
        case .modelNotReady:
            "The on-device language model is still downloading or not ready. Try again later."
        @unknown default:
            "Apple Intelligence is not available right now. You can still write or edit the message manually."
        }
    }
#endif
}

struct AppleGreetingGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: GreetingGenerationContext
    let onUse: (String) -> Void

    @State private var tone = "Warm"
    @State private var details = ""
    @State private var generatedText = ""
    @State private var variants: [String] = []
    @State private var selectedVariant = 0
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private let tones = ["Warm", "Professional", "Friendly", "Heartfelt", "Brief"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Direction") {
                    Picker("Tone", selection: $tone) {
                        ForEach(tones, id: \.self) { Text($0).tag($0) }
                    }

                    TextField("Optional details or guidance", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Context") {
                    LabeledContent("Occasion", value: context.occasion)
                    LabeledContent("Audience", value: context.relationship)
                    LabeledContent("Channel", value: context.channel)
                    LabeledContent("Language", value: context.language)
                }

                if !generatedText.isEmpty {
                    Section("Generated message") {
                        if variants.count > 1 {
                            Picker("Variant", selection: $selectedVariant) {
                                ForEach(variants.indices, id: \.self) { index in
                                    Text("Option \(index + 1)").tag(index)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedVariant) { _, index in
                                guard variants.indices.contains(index) else { return }
                                generatedText = variants[index]
                            }
                        }
                        TextEditor(text: $generatedText)
                            .frame(minHeight: 150)
                    }
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            Label(
                                generatedText.isEmpty ? "Generate message" : "Generate another",
                                systemImage: "apple.intelligence"
                            )
                            Spacer()
                            if isGenerating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isGenerating || !isModelAvailable)
                    if !generatedText.isEmpty {
                        Menu {
                            Button("Rewrite") { refine("Rewrite this message with fresh wording while preserving its meaning.") }
                            Button("Shorten") { refine("Shorten this message to one or two concise sentences.") }
                            Button("Translate to \(context.language)") { refine("Translate this message into \(context.language), preserving its warmth and intent.") }
                        } label: {
                            Label("Improve message", systemImage: "wand.and.stars")
                        }
                        .disabled(isGenerating)
                    }
                } footer: {
                    Text(availabilityExplanation)
                }
            }
            .navigationTitle("Apple Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        onUse(generatedText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Generation unavailable", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var isModelAvailable: Bool {
        if case .available = AppleGreetingGenerator.status { return true }
        return false
    }

    private var availabilityExplanation: String {
        switch AppleGreetingGenerator.status {
        case .available:
            "Generated privately on this device. Review the message before using it."
        case .unavailable(let reason):
            reason
        }
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            defer { isGenerating = false }
            do {
                var generated: [String] = []
                for number in 1...3 {
                    let direction = details + "\nCreate distinct option \(number) with different phrasing."
                    generated.append(try await AppleGreetingGenerator.generate(context: context, tone: tone, details: direction))
                }
                variants = generated
                selectedVariant = 0
                generatedText = generated[0]
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refine(_ instruction: String) {
        isGenerating = true
        errorMessage = nil
        Task {
            defer { isGenerating = false }
            do {
                let direction = "Existing draft:\n\(generatedText)\n\n\(instruction)"
                let refined = try await AppleGreetingGenerator.generate(context: context, tone: tone, details: direction)
                generatedText = refined
                variants = [refined]
                selectedVariant = 0
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
