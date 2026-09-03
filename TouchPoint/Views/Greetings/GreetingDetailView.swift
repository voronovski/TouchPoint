import SwiftUI
import MessageUI

struct GreetingDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    var showsDoneButton = false
    @State private var composerRequest: ComposerRequest?
    @State private var composerError: String?
    @State private var messageEditorRequest: MessageEditorRequest?
    @State private var showingSkipConfirmation = false

    private var event: GreetingEvent? {
        store.event(id: eventID)
    }

    var body: some View {
        ScrollView {
            if let event, let person = store.person(for: event) {
                VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    SurfaceCard {
                        HStack(alignment: .top, spacing: 12) {
                            PersonAvatar(person: person, size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(.headline)
                                Label(event.occasion.title, systemImage: event.occasion.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(status: store.status(for: event))
                        }
                        .padding(TouchPointMetric.cardPadding)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "Schedule")
                        SurfaceCard {
                            VStack(spacing: 0) {
                                detailRow(
                                    icon: "calendar",
                                    title: "Recipient date",
                                    value: event.date.touchPointDay(in: person.timeZoneIdentifier)
                                )
                                Divider().padding(.leading, 52)
                                detailRow(
                                    icon: "clock",
                                    title: "Recipient time",
                                    value: event.date.touchPointTime(in: person.timeZoneIdentifier)
                                )
                                Divider().padding(.leading, 52)
                                detailRow(icon: event.method.icon, title: "Action", value: event.method.title)
                                Divider().padding(.leading, 52)
                                detailRow(icon: "globe", title: "Time zone", value: person.timeZoneIdentifier.replacingOccurrences(of: "_", with: " "))
                                if person.timeZoneIdentifier != TimeZone.current.identifier {
                                    Divider().padding(.leading, 52)
                                    detailRow(
                                        icon: "clock.arrow.circlepath",
                                        title: "Your time",
                                        value: "\(event.date.touchPointDay), \(event.date.touchPointTime)"
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "Message", actionTitle: "Edit") {
                            messageEditorRequest = MessageEditorRequest(
                                id: event.id,
                                message: event.message,
                                personName: person.name,
                                relationship: person.relationship,
                                occasion: event.occasion,
                                method: event.method,
                                language: person.preferredLanguage
                            )
                        }
                        SurfaceCard {
                            Text(event.message.isEmpty ? "No message has been added yet." : event.message)
                                .font(.body)
                                .foregroundStyle(event.message.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }

                    if ![.completed, .skipped].contains(store.status(for: event)) {
                        Button {
                            beginContact(for: event, person: person)
                        } label: {
                            PrimaryButtonLabel(title: actionTitle(for: event.method), systemImage: event.method.icon)
                        }
                        .buttonStyle(TouchPointPrimaryButtonStyle())

                        Button(role: .destructive) {
                            showingSkipConfirmation = true
                        } label: {
                            Label("Skip this greeting", systemImage: "forward.end")
                                .frame(maxWidth: .infinity)
                        }
                    } else if store.status(for: event) == .skipped {
                        Button {
                            store.restoreGreeting(id: event.id)
                        } label: {
                            Label("Restore greeting", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.vertical, 18)
            } else {
                ContentUnavailableView("Greeting unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Greeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $composerRequest) { request in
            switch request.kind {
            case .message:
                MessageComposerView(request: request) { result in
                    composerRequest = nil
                    if result == .sent {
                        store.completeGreeting(id: eventID)
                    } else if result == .failed {
                        composerError = "Messages could not prepare the text. Please try again."
                    }
                }
            case .email:
                MailComposerView(request: request) { result, error in
                    composerRequest = nil
                    if result == .sent {
                        store.completeGreeting(id: eventID)
                    } else if result == .failed {
                        composerError = error?.localizedDescription ?? "Mail could not prepare the message."
                    }
                }
            }
        }
        .sheet(item: $messageEditorRequest) { request in
            GreetingMessageEditor(
                message: request.message,
                context: GreetingGenerationContext(
                    occasion: request.occasion.title,
                    relationship: request.relationship.title,
                    channel: request.method.title,
                    language: request.language,
                    recipientName: request.personName.split(separator: " ").first.map(String.init),
                    usesNamePlaceholder: false
                ),
                onSave: { message in
                    store.updateGreetingMessage(id: request.id, message: message)
                    messageEditorRequest = nil
                },
                onSaveAsTemplate: { message in
                    store.addTemplate(GreetingTemplate(
                        title: "\(request.occasion.title) message",
                        occasions: [request.occasion],
                        body: message,
                        iconSemantic: "occasion",
                        iconID: request.occasion.icon,
                        colorToken: request.occasion.defaultColorToken,
                        relationships: [request.relationship],
                        channels: [request.method],
                        languages: [request.language]
                    ))
                }
            )
        }
        .alert("Cannot open composer", isPresented: Binding(
            get: { composerError != nil },
            set: { if !$0 { composerError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(composerError ?? "")
        }
        .confirmationDialog("Skip this greeting?", isPresented: $showingSkipConfirmation, titleVisibility: .visible) {
            Button("Skip greeting", role: .destructive) {
                store.skipGreeting(id: eventID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will remain in Calendar and can be restored later.")
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            IconTile(systemImage: icon)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(TouchPointMetric.cardPadding)
    }

    private func actionTitle(for method: ContactMethod) -> String {
        switch method {
        case .sms: "Open Messages"
        case .email: "Open Mail"
        case .reminder: "Mark complete"
        }
    }

    private func beginContact(for event: GreetingEvent, person: Person) {
        switch event.method {
        case .sms:
            guard !person.phone.isEmpty else {
                composerError = "Add a phone number for \(person.name) first."
                return
            }
            guard MessageComposerView.isAvailable else {
                composerError = "Messages is not available on this device. Try again on an iPhone with messaging configured."
                return
            }
            composerRequest = ComposerRequest(
                kind: .message,
                recipient: person.phone,
                subject: "",
                body: event.message
            )
        case .email:
            guard !person.email.isEmpty else {
                composerError = "Add an email address for \(person.name) first."
                return
            }
            guard MailComposerView.isAvailable else {
                composerError = "Mail is not configured on this device. Add a Mail account and try again."
                return
            }
            composerRequest = ComposerRequest(
                kind: .email,
                recipient: person.email,
                subject: event.subject ?? event.occasion.title,
                body: event.message
            )
        case .reminder:
            store.completeGreeting(id: event.id)
        }
    }
}

private struct MessageEditorRequest: Identifiable {
    let id: UUID
    let message: String
    let personName: String
    let relationship: Relationship
    let occasion: Occasion
    let method: ContactMethod
    let language: String
}

private struct GreetingMessageEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: String
    @State private var showingGenerator = false
    @State private var didSaveTemplate = false
    let context: GreetingGenerationContext
    let onSave: (String) -> Void
    let onSaveAsTemplate: (String) -> Void

    init(
        message: String,
        context: GreetingGenerationContext,
        onSave: @escaping (String) -> Void,
        onSaveAsTemplate: @escaping (String) -> Void
    ) {
        _message = State(initialValue: message)
        self.context = context
        self.onSave = onSave
        self.onSaveAsTemplate = onSaveAsTemplate
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                } header: {
                    Text("Personal message")
                } footer: {
                    Text("This is the exact text TouchPoint will place in Messages or Mail.")
                }

                Section {
                    Button { showingGenerator = true } label: {
                        Label("Generate with Apple Intelligence", systemImage: "apple.intelligence")
                    }
                    Button {
                        onSaveAsTemplate(trimmedMessage)
                        didSaveTemplate = true
                    } label: {
                        Label(didSaveTemplate ? "Saved to templates" : "Save as template", systemImage: didSaveTemplate ? "checkmark" : "rectangle.stack.badge.plus")
                    }
                    .disabled(trimmedMessage.isEmpty || didSaveTemplate)
                }
            }
            .navigationTitle("Edit message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(trimmedMessage) }
                        .disabled(trimmedMessage.isEmpty)
                }
            }
            .sheet(isPresented: $showingGenerator) {
                AppleGreetingGeneratorSheet(context: context) { message = $0 }
            }
        }
    }
}
