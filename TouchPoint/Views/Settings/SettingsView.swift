import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var notificationError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Focus.allCases) { focus in
                        Button {
                            preferences.focus = focus
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                IconTile(
                                    systemImage: focus.icon,
                                    tint: preferences.focus == focus ? .accentColor : .secondary
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(focus.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(focus.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if preferences.focus == focus {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Focus")
                } footer: {
                    Text("Focus adjusts which relationships and priorities appear first. Your people, dates, templates, and plans stay unchanged.")
                }

                Section {
                    LabeledContent {
                        Text(notificationStatusTitle)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Local reminders", systemImage: "bell")
                    }

                    switch notificationStatus {
                    case .notDetermined:
                        Button {
                            enableReminders()
                        } label: {
                            Label("Enable reminders", systemImage: "bell.badge")
                        }
                    case .denied:
                        Button {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        } label: {
                            Label("Open System Settings", systemImage: "gear")
                        }
                    default:
                        EmptyView()
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Touch Point uses on-device notifications for upcoming actions. It never sends the greeting for you.")
                }

                Section("About") {
                    LabeledContent("App", value: "Touch Point")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await refreshNotificationStatus()
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task { await refreshNotificationStatus() }
            }
            .alert("Reminders unavailable", isPresented: Binding(
                get: { notificationError != nil },
                set: { if !$0 { notificationError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notificationError ?? "")
            }
        }
    }

    private var notificationStatusTitle: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            "Enabled"
        case .denied:
            "Off"
        case .notDetermined:
            "Not enabled"
        case nil:
            "Checking"
        @unknown default:
            "Unavailable"
        }
    }

    private func enableReminders() {
        Task {
            do {
                let granted = try await LocalNotificationScheduler.requestAuthorization()
                await refreshNotificationStatus()
                guard granted else { return }
                try await LocalNotificationScheduler.synchronize(
                    events: store.events,
                    people: store.people
                )
            } catch {
                notificationError = error.localizedDescription
            }
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await LocalNotificationScheduler.authorizationStatus()
    }
}
