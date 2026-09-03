import SwiftUI
import MessageUI

struct GreetingDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    var showsDoneButton = false
    @State private var composerRequest: ComposerRequest?
    @State private var composerError: String?

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
                                Label(event.occasion.rawValue, systemImage: event.occasion.icon)
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
                                detailRow(icon: "calendar", title: "Date", value: event.date.touchPointDay)
                                Divider().padding(.leading, 52)
                                detailRow(icon: "clock", title: "Time", value: event.date.touchPointTime)
                                Divider().padding(.leading, 52)
                                detailRow(icon: event.method.icon, title: "Action", value: event.method.rawValue)
                                Divider().padding(.leading, 52)
                                detailRow(icon: "globe", title: "Time zone", value: person.timeZoneIdentifier.replacingOccurrences(of: "_", with: " "))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "Message")
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
        .alert("Cannot open composer", isPresented: Binding(
            get: { composerError != nil },
            set: { if !$0 { composerError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(composerError ?? "")
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
                subject: event.occasion.rawValue,
                body: event.message
            )
        case .reminder:
            store.completeGreeting(id: event.id)
        }
    }
}
