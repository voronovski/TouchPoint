import SwiftUI

struct GreetingDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    var showsDoneButton = false

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
                            StatusPill(status: event.status)
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
                                detailRow(icon: event.delivery.icon, title: "Delivery", value: event.delivery.rawValue)
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

                    if event.status == .approval {
                        Button {
                            store.approveGreeting(id: event.id)
                        } label: {
                            PrimaryButtonLabel(title: "Approve greeting", systemImage: "checkmark")
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
}
