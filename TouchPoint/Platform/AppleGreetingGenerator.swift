import Foundation
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
    var occasionDetails: String = ""
    var eventDate: String = ""
    var senderName: String = ""
}

enum AppleGreetingGeneratorStatus: Equatable {
    case available
    case unavailable(String)
}

enum AppleGreetingGeneratorError: LocalizedError {
    case unsupportedOS
    case modelUnavailable(String)
    case unsupportedLocale(String)
    case emptyResponse
    case invalidPlaceholder

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            "Apple Intelligence generation requires iOS 26 or later."
        case .modelUnavailable(let reason):
            reason
        case .unsupportedLocale(let language):
            "Apple Intelligence does not support \(language). Choose another language or write the message manually."
        case .emptyResponse:
            "Apple Intelligence returned an empty message. Please try again."
        case .invalidPlaceholder:
            "The generated message used an unsupported template variable. Please generate again or edit it manually."
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
    static func status(for language: String) -> AppleGreetingGeneratorStatus {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return status }

        let model = SystemLanguageModel.default
        guard let locale = locale(for: language), model.supportsLocale(locale) else {
            let displayLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
            return .unavailable(
                "Apple Intelligence does not support \(displayLanguage.isEmpty ? "the selected language" : displayLanguage). Choose another language or write the message manually."
            )
        }
        switch model.availability {
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
        guard let locale = locale(for: context.language), model.supportsLocale(locale) else {
            let language = context.language.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppleGreetingGeneratorError.unsupportedLocale(language.isEmpty ? "the selected language" : language)
        }

        let session = LanguageModelSession(instructions: """
        You write thoughtful, natural greeting messages for a relationship reminder app.
        Return exactly one finished message body. Never return a numbered list, multiple options, alternatives, a title, quotation marks, or analysis.
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

        let normalizedSenderName = context.senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let senderInstruction: String
        if normalizedSenderName.isEmpty {
            senderInstruction = "The sender's name is not provided. Do not invent a sender name or signature."
        } else if context.usesNamePlaceholder {
            senderInstruction = "The sender is \(normalizedSenderName). Write from that sender's perspective. If a sign-off is appropriate, use the literal placeholder {{sender_name}} instead of writing the sender's name directly."
        } else {
            senderInstruction = "The sender is \(normalizedSenderName). Write from that sender's perspective. Do not add a signature unless the requested style or additional direction calls for one."
        }

        let extraDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let occasionDetails = context.occasionDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let eventDate = context.eventDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        Write exactly one greeting with these constraints:
        Occasion label: \(context.occasion)
        Occasion meaning and event context: \(occasionDetails.isEmpty ? "Use the occasion label literally." : occasionDetails)
        Event date or timing: \(eventDate.isEmpty ? "Not specified" : eventDate)
        Relationship: \(context.relationship)
        Delivery channel: \(context.channel)
        Language: \(context.language)
        Tone: \(tone)
        \(nameInstruction)
        \(senderInstruction)
        Additional direction: \(extraDetails.isEmpty ? "None" : extraDetails)
        Keep it concise enough for the delivery channel.
        Output only the single message that will be sent.
        """

        let response = try await session.respond(to: prompt)
        let text = normalizedSingleMessage(response.content)
        guard !text.isEmpty else { throw AppleGreetingGeneratorError.emptyResponse }
        let placeholderCount = text.components(separatedBy: "{{first_name}}").count - 1
        if context.usesNamePlaceholder {
            guard placeholderCount == 1 else { throw AppleGreetingGeneratorError.invalidPlaceholder }
            let unsupportedTokens = placeholderTokens(in: text).subtracting(["first_name", "sender_name"])
            guard unsupportedTokens.isEmpty else { throw AppleGreetingGeneratorError.invalidPlaceholder }
            let textWithoutSupportedTokens = text
                .replacingOccurrences(of: "{{first_name}}", with: "")
                .replacingOccurrences(of: "{{sender_name}}", with: "")
            guard !textWithoutSupportedTokens.contains("{{"),
                  !textWithoutSupportedTokens.contains("}}") else {
                throw AppleGreetingGeneratorError.invalidPlaceholder
            }
        } else if text.contains("{{") || text.contains("}}") {
            throw AppleGreetingGeneratorError.invalidPlaceholder
        }
        return text
#else
        throw AppleGreetingGeneratorError.unsupportedOS
#endif
    }

    /// Foundation Models can occasionally ignore the one-message instruction and
    /// return a labeled list. Keep each UI variant atomic even in that fallback case.
    static func normalizedSingleMessage(_ response: String) -> String {
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        let labels = [
            "option", "variant", "version", "draft", "message",
            "вариант", "версия", "черновик", "сообщение",
            "opción", "alternativa", "versión", "borrador", "mensaje",
            "variante", "brouillon", "entwurf", "nachricht",
            "opzione", "versione", "bozza", "messaggio",
            "opção", "versão", "rascunho", "mensagem",
            "案", "選択肢", "选项", "選項", "版本", "옵션", "메시지"
        ].joined(separator: "|")
        let labeledPattern = #"(?im)^[\t ]*(?:[-*][\t ]*)?(?:"# + labels + #")[\t ]*(?:#[\t ]*)?\d+[\t ]*(?:[:.)-][\t ]*|$)"#
        if let regex = try? NSRegularExpression(pattern: labeledPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            if let first = matches.first,
               let contentStart = Range(first.range, in: text)?.upperBound {
                let contentEnd = matches.dropFirst().first
                    .flatMap { Range($0.range, in: text)?.lowerBound }
                    ?? text.endIndex
                return String(text[contentStart..<contentEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let numberedPattern = #"(?m)^[\t ]*\d+[.)][\t ]+"#
        if let regex = try? NSRegularExpression(pattern: numberedPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            if matches.count > 1,
               let first = matches.first,
               let start = Range(first.range, in: text)?.upperBound,
               let second = Range(matches[1].range, in: text)?.lowerBound {
                return String(text[start..<second]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let bulletPattern = #"(?m)^[\t ]*[-*•][\t ]+"#
        if let regex = try? NSRegularExpression(pattern: bulletPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            if matches.count > 1,
               let first = matches.first,
               let start = Range(first.range, in: text)?.upperBound,
               let second = Range(matches[1].range, in: text)?.lowerBound {
                return String(text[start..<second]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }

    private static func placeholderTokens(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{([A-Za-z0-9_]+)\}\}"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[tokenRange])
        })
    }

    private static func locale(for language: String) -> Locale? {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let identifiers = [
            "english": "en", "spanish": "es", "french": "fr", "german": "de",
            "italian": "it", "portuguese": "pt", "japanese": "ja", "korean": "ko",
            "chinese": "zh", "russian": "ru",
            "английский": "en", "испанский": "es", "французский": "fr", "немецкий": "de",
            "итальянский": "it", "португальский": "pt", "японский": "ja", "корейский": "ko",
            "китайский": "zh", "русский": "ru"
        ]
        if let identifier = identifiers[normalized] {
            return Locale(identifier: identifier)
        }
        if normalized.count == 2 || normalized.contains("-") || normalized.contains("_") {
            return Locale(identifier: normalized)
        }
        return nil
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
    @State private var context: GreetingGenerationContext
    let onUse: (String) -> Void

    @State private var tone = "Warm"
    @State private var details = ""
    @State private var generatedText = ""
    @State private var variants: [String] = []
    @State private var selectedVariant = 0
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showsContext = false

    private let tones = ["Warm", "Professional", "Friendly", "Heartfelt", "Brief"]

    init(context: GreetingGenerationContext, onUse: @escaping (String) -> Void) {
        _context = State(initialValue: context)
        self.onUse = onUse
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    availabilityCard
                    directionSection
                    contextSection

                    if !generatedText.isEmpty {
                        generatedMessageSection
                    }
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.vertical, 18)
            }
            .background(Color(.systemGroupedBackground))
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
            .safeAreaInset(edge: .bottom) {
                generateAction
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

    private var availabilityCard: some View {
        SurfaceCard {
            HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                IconTile(
                    systemImage: isModelAvailable ? "apple.intelligence" : "exclamationmark.triangle.fill",
                    tint: isModelAvailable ? .accentColor : TouchPointColor.amber
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Generate message")
                        .font(.headline)
                    Text(availabilityExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(TouchPointMetric.cardPadding)
        }
    }

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Direction")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            SurfaceCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "slider.horizontal.3", tint: .accentColor)
                        Text("Tone")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("Tone", selection: $tone) {
                            ForEach(tones, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    .padding(TouchPointMetric.cardPadding)

                    Divider().padding(.leading, 52)

                    TextField("Optional details or guidance", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(TouchPointMetric.cardPadding)
                }
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Context")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            SurfaceCard {
                DisclosureGroup(isExpanded: $showsContext) {
                    VStack(spacing: 0) {
                        Divider().padding(.leading, 52)
                        contextField("Occasion", text: $context.occasion)
                        Divider().padding(.leading, 52)
                        contextField("Event context", text: $context.occasionDetails, axis: .vertical)
                        Divider().padding(.leading, 52)
                        contextValueRow("Date or timing", value: context.eventDate)
                        Divider().padding(.leading, 52)
                        contextValueRow("Audience", value: context.relationship)
                        Divider().padding(.leading, 52)
                        contextValueRow("Channel", value: context.channel)
                        Divider().padding(.leading, 52)
                        contextValueRow("Language", value: context.language)
                        Divider().padding(.leading, 52)
                        contextField("Sender (optional)", text: $context.senderName)
                    }
                } label: {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "text.page", tint: .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.occasion)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(context.language)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .padding(TouchPointMetric.cardPadding)
            }

            Text("You can adjust this context for the generated text. The event, person, and template are not changed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var generatedMessageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generated message")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            SurfaceCard {
                VStack(spacing: 12) {
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
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)

                    Menu {
                        Button("Rewrite") { refine("Rewrite this message with fresh wording while preserving its meaning.") }
                        Button("Shorten") { refine("Shorten this message to one or two concise sentences.") }
                        Button("Translate to \(context.language)") { refine("Translate this message into \(context.language), preserving its warmth and intent.") }
                    } label: {
                        Label("Improve message", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                    .disabled(isGenerating || !isModelAvailable)
                }
                .padding(TouchPointMetric.cardPadding)
            }
        }
    }

    private var generateAction: some View {
        Button {
            generate()
        } label: {
            HStack(spacing: 8) {
                Label(
                    generatedText.isEmpty ? "Generate message" : "Generate another",
                    systemImage: "apple.intelligence"
                )
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
        }
        .buttonStyle(TouchPointPrimaryButtonStyle())
        .disabled(isGenerating || !isModelAvailable)
        .opacity(isGenerating || !isModelAvailable ? 0.45 : 1)
        .padding(.horizontal, TouchPointMetric.screenPadding)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func contextField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: text, prompt: Text(title), axis: axis)
                .lineLimit(axis == .vertical ? 2...4 : 1...1)
                .accessibilityLabel(Text(title))
        }
        .padding(.leading, 40)
        .padding(.vertical, 10)
    }

    private func contextValueRow(_ title: LocalizedStringKey, value: String) -> some View {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return LabeledContent {
            Text(normalizedValue.isEmpty ? String(localized: "Not specified") : normalizedValue)
                .foregroundStyle(normalizedValue.isEmpty ? Color.secondary : Color.primary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 40)
        .padding(.vertical, 10)
    }

    private var isModelAvailable: Bool {
        if case .available = generatorStatus { return true }
        return false
    }

    private var generatorStatus: AppleGreetingGeneratorStatus {
        AppleGreetingGenerator.status(for: context.language)
    }

    private var availabilityExplanation: String {
        switch generatorStatus {
        case .available:
            "Generated privately on this device. Review the message before using it."
        case .unavailable(let reason):
            reason
        }
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        let requestedContext = context
        let requestedTone = tone
        let requestedDetails = details
        Task {
            defer { isGenerating = false }
            do {
                var generated: [String] = []
                let variationDirections = [
                    "Use direct, natural phrasing.",
                    "Use fresh wording and a different sentence structure.",
                    "Use another natural approach while honoring every event detail."
                ]
                for variation in variationDirections {
                    let direction = [requestedDetails, variation, "Return one message only."]
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                    generated.append(
                        try await AppleGreetingGenerator.generate(
                            context: requestedContext,
                            tone: requestedTone,
                            details: direction
                        )
                    )
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
        let requestedContext = context
        let requestedTone = tone
        let existingDraft = generatedText
        Task {
            defer { isGenerating = false }
            do {
                let direction = "Existing draft:\n\(existingDraft)\n\n\(instruction)"
                let refined = try await AppleGreetingGenerator.generate(
                    context: requestedContext,
                    tone: requestedTone,
                    details: direction
                )
                generatedText = refined
                variants = [refined]
                selectedVariant = 0
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
