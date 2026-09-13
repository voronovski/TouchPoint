import SwiftUI
import MessageUI

struct GreetingDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    var showsDoneButton = false
    @State private var composerRequest: ComposerRequest?
    @State private var composerError: String?
    @State private var messageEditorRequest: MessageEditorRequest?
    @State private var showingSkipConfirmation = false
    @State private var showingScheduleEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var refreshTick = Date()

    private var event: GreetingEvent? {
        store.event(id: eventID)
    }

    var body: some View {
        ScrollView {
            if let event, let person = store.person(for: event) {
                VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    SurfaceCard {
                        HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                            PersonAvatar(person: person, size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(.headline)
                                Label(eventDisplayName(event), systemImage: event.occasion.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(status: store.status(for: event))
                        }
                        .padding(TouchPointMetric.cardPadding)
                    }

                    if event.customName != nil || event.recurrence == .oneTime {
                        SurfaceCard {
                            HStack(spacing: 12) {
                                IconTile(systemImage: event.recurrence == .oneTime ? "arrow.right" : "tag")
                                VStack(alignment: .leading, spacing: 2) {
                                    if let customName = event.customName, !customName.isEmpty {
                                        Text(customName).font(.subheadline.weight(.semibold))
                                    }
                                    Text(event.recurrence == .oneTime ? "One-time greeting" : "Repeats annually")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(TouchPointMetric.cardPadding)
                        }
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
                                occasionName: event.displayName,
                                occasionDetails: event.occasion.generationContextDescription
                                    + " This greeting is "
                                    + (event.recurrence == .annual ? "an annual occurrence." : "a one-time event."),
                                eventDate: "\(event.date.touchPointDay(in: person.timeZoneIdentifier)) at \(event.date.touchPointTime(in: person.timeZoneIdentifier)) in the recipient's time zone.",
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

                        if let sourceTemplateID = event.sourceTemplateID,
                           let sourceTemplate = store.templates.first(where: { $0.id == sourceTemplateID }) {
                            let revision = event.sourceTemplateRevision ?? sourceTemplate.revisionNumber
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Based on \(sourceTemplate.title), version \(revision)")
                                    Text("Scheduled text won't change when this template is updated.")
                                }
                            } icon: {
                                Image(systemName: "info.circle")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit schedule", systemImage: "calendar.badge.clock") {
                        showingScheduleEditor = true
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label { Text("Delete greeting") } icon: { TouchPointTrashIcon() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Greeting actions")
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
                    occasion: request.occasionName,
                    relationship: request.relationship.title,
                    channel: request.method.title,
                    language: request.language,
                    recipientName: request.personName.split(separator: " ").first.map(String.init),
                    usesNamePlaceholder: false,
                    occasionDetails: request.occasionDetails,
                    eventDate: request.eventDate,
                    senderName: preferences.senderName
                ),
                onSave: { message in
                    if store.updateGreetingMessage(id: request.id, message: message) {
                        messageEditorRequest = nil
                    }
                },
                onSaveAsTemplate: { message in
                    let templateMessage = messageForTemplate(message, recipientName: request.personName)
                    return store.addTemplate(GreetingTemplate(
                        title: "\(request.occasion.title) message",
                        occasions: [request.occasion],
                        body: templateMessage,
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
        .sheet(isPresented: $showingScheduleEditor) {
            if let event, let person = store.person(for: event) {
                GreetingScheduleEditor(event: event, availableMethods: store.availableContactMethods(for: person)) { updated in
                    var resolved = updated
                    resolved.method = store.resolvedContactMethod(for: person, preferred: updated.method) ?? .reminder
                    return store.updateGreeting(resolved)
                }
            }
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
        .confirmationDialog("Delete this greeting?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete greeting", role: .destructive) {
                if store.deleteGreeting(id: eventID) { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the scheduled greeting and cannot be undone.")
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                refreshTick = .now
            }
        }
    }

    private func eventDisplayName(_ event: GreetingEvent) -> String {
        event.displayName
    }

    private func messageForTemplate(_ message: String, recipientName: String) -> String {
        let fullName = recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstName = fullName.split(separator: " ").first.map(String.init) ?? fullName
        guard !firstName.isEmpty else { return message }
        return message
            .replacingOccurrences(of: fullName, with: "{{first_name}}", options: .caseInsensitive)
            .replacingOccurrences(of: firstName, with: "{{first_name}}", options: .caseInsensitive)
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
        case .sms: String(localized: "Open Messages")
        case .email: String(localized: "Open Mail")
        case .reminder: String(localized: "Mark complete")
        }
    }

    private func beginContact(for event: GreetingEvent, person: Person) {
        guard store.people.first(where: { $0.id == person.id })?.communicationStopped == false else {
            composerError = String(localized: "Communication with this person is stopped. Turn off Stop communication in their profile before planning greetings.")
            return
        }
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
    let occasionName: String
    let occasionDetails: String
    let eventDate: String
    let method: ContactMethod
    let language: String
}

private struct GreetingScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GreetingEvent
    let availableMethods: [ContactMethod]
    @State private var saveError: String?
    let onSave: (GreetingEvent) -> Bool

    init(event: GreetingEvent, availableMethods: [ContactMethod], onSave: @escaping (GreetingEvent) -> Bool) {
        _draft = State(initialValue: event)
        self.availableMethods = availableMethods
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    DatePicker("Date and time", selection: $draft.date)
                    Picker("Contact method", selection: $draft.method) {
                        ForEach(availableMethods) { method in
                            Label(method.title, systemImage: method.icon).tag(method)
                        }
                    }
                    Picker("Recurrence", selection: $draft.recurrence) {
                        Text("Every year").tag(EventRecurrence.annual)
                        Text("One time").tag(EventRecurrence.oneTime)
                    }
                }

                Section("Occasion") {
                    TextField(
                        draft.occasion == .custom
                            ? String(localized: "Custom occasion name")
                            : String(localized: "Custom occasion name (optional)"),
                        text: Binding(
                        get: { draft.customName ?? "" },
                        set: { draft.customName = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    ))
                    if draft.occasion == .custom {
                        Text("A custom occasion needs a name.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = draft.customName?.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.customName = trimmedName?.isEmpty == false ? trimmedName : nil
                        if onSave(draft) {
                            dismiss()
                        } else {
                            saveError = "Touch Point could not save this schedule."
                        }
                    }
                    .disabled(
                        draft.occasion == .custom
                            && draft.customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
                    )
                }
            }
            .alert("Schedule not saved", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }
}

private struct GreetingMessageEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: String
    @State private var showingGenerator = false
    @State private var didSaveTemplate = false
    let context: GreetingGenerationContext
    let onSave: (String) -> Void
    let onSaveAsTemplate: (String) -> Bool

    init(
        message: String,
        context: GreetingGenerationContext,
        onSave: @escaping (String) -> Void,
        onSaveAsTemplate: @escaping (String) -> Bool
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
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                    .disabled(!isGeneratorAvailable)
                    Button {
                        didSaveTemplate = onSaveAsTemplate(trimmedMessage)
                    } label: {
                        if didSaveTemplate {
                            Label("Saved to templates", systemImage: "checkmark")
                        } else {
                            Label("Save as template", systemImage: "rectangle.stack.badge.plus")
                        }
                    }
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                    .disabled(trimmedMessage.isEmpty || didSaveTemplate)
                } footer: {
                    Text(generatorAvailabilityExplanation)
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

    private var generatorStatus: AppleGreetingGeneratorStatus {
        AppleGreetingGenerator.status(for: context.language)
    }

    private var isGeneratorAvailable: Bool {
        if case .available = generatorStatus { return true }
        return false
    }

    private var generatorAvailabilityExplanation: String {
        switch generatorStatus {
        case .available:
            String(localized: "Apple Intelligence generation happens privately on this device.")
        case .unavailable(let reason):
            reason
        }
    }
}
