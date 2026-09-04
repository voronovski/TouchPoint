import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(CloudKitSnapshotService.self) private var cloudKit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var notificationError: String?
    @State private var isSynchronizingNotifications = false
    @State private var isSynchronizingCloudKit = false
    @State private var exportDocument: TouchPointArchiveDocument?
    @State private var showingArchiveExporter = false
    @State private var showingArchiveImporter = false
    @State private var archiveError: String?
    @State private var templateExportDocument = TemplateLibraryDocument()
    @State private var showingTemplateExporter = false
    @State private var showingTemplateImporter = false
    @State private var templateTransferError: String?
    @State private var showingRecoveryConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                personalizationSettingsSection
                occasionGroupsSettingsSection
                focusSettingsSection
                remindersSettingsSection
                aboutSettingsSection
                cloudSettingsSection
                templateLibrarySettingsSection
                archiveSettingsSection
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
            .alert("Archive unavailable", isPresented: Binding(
                get: { archiveError != nil },
                set: { if !$0 { archiveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(archiveError ?? "")
            }
            .alert("Template library", isPresented: Binding(
                get: { templateTransferError != nil },
                set: { if !$0 { templateTransferError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(templateTransferError ?? "")
            }
            .confirmationDialog("Restore recovered local backup?", isPresented: $showingRecoveryConfirmation, titleVisibility: .visible) {
                Button("Restore backup", role: .destructive) { restoreRecoveredSnapshot() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The recovered file will replace the current in-memory data only after it passes validation and saves successfully.")
            }
            .fileImporter(isPresented: $showingArchiveImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                importArchive(result)
            }
            .fileImporter(isPresented: $showingTemplateImporter, allowedContentTypes: [.json]) { result in
                importTemplateLibrary(result)
            }
            .fileExporter(
                isPresented: $showingArchiveExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "TouchPoint-Archive.json"
            ) { result in
                if case .failure(let error) = result { archiveError = error.localizedDescription }
            }
            .fileExporter(
                isPresented: $showingTemplateExporter,
                document: templateExportDocument,
                contentType: .json,
                defaultFilename: "TouchPoint Templates"
            ) { result in
                if case .failure(let error) = result { templateTransferError = error.localizedDescription }
            }
        }
    }

    private var personalizationSettingsSection: some View {
        Section {
            TextField("Your name", text: Binding(
                get: { preferences.senderName },
                set: { preferences.senderName = $0 }
            ))
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            Picker("Default language", selection: Binding(
                get: { preferences.preferredLanguage },
                set: { preferences.preferredLanguage = $0 }
            )) {
                ForEach(TouchPointLanguage.supported, id: \.self) { language in
                    Text(language).tag(language)
                }
            }
        } header: {
            Text("Personalization")
        } footer: {
            Text("Your name is used as the sender. The default language is selected automatically for every new template.")
        }
    }

    private var occasionGroupsSettingsSection: some View {
        Section {
            NavigationLink {
                OccasionGroupsSettingsView()
            } label: {
                HStack {
                    Label("Occasion groups", systemImage: "calendar.badge.clock")
                    Spacer()
                    Text("\(enabledOccasionGroupCount)/\(configurableOccasionGroupCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        } footer: {
            Text("Choose which occasion groups are relevant. Disabled groups are hidden from occasion pickers; saved dates, templates, and greetings stay unchanged.")
        }
    }

    private var configurableOccasionGroupCount: Int {
        configurableOccasionGroups.count
    }

    private var enabledOccasionGroupCount: Int {
        configurableOccasionGroups.filter { !preferences.disabledOccasionCategories.contains($0) }.count
    }

    private var configurableOccasionGroups: [OccasionCategory] {
        OccasionCategory.allCases.filter { $0 != .personal }
    }

    private var focusSettingsSection: some View {
        Section {
            ForEach(Focus.allCases) { focus in
                Button { preferences.focus = focus } label: {
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(systemImage: focus.icon, tint: preferences.focus == focus ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(focus.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(focus.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if preferences.focus == focus {
                            Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(.accent)
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
    }

    private var remindersSettingsSection: some View {
        Section {
            LabeledContent {
                Text(notificationStatusTitle).foregroundStyle(.secondary)
            } label: {
                Label("Local reminders", systemImage: "bell")
            }
            reminderAuthorizationAction
            VStack(alignment: .leading, spacing: 10) {
                Text("Remind me").font(.subheadline.weight(.semibold))
                ForEach([0, 1, 3, 7], id: \.self) { days in reminderLeadTimeRow(days) }
                DatePicker("Reminder time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                Toggle("Hide names in notifications", isOn: Binding(
                    get: { preferences.hideReminderNames },
                    set: { preferences.hideReminderNames = $0 }
                ))
            }
            Button { synchronizeNotificationsNow() } label: {
                Label(isSynchronizingNotifications ? "Syncing reminders…" : "Sync reminders now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSynchronizingNotifications)
            if let syncError = preferences.notificationSyncError {
                Label(syncError, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Touch Point uses on-device notifications for upcoming actions. It never sends the greeting for you.")
        }
    }

    @ViewBuilder
    private var reminderAuthorizationAction: some View {
        switch notificationStatus {
        case .notDetermined:
            Button { enableReminders() } label: { Label("Enable reminders", systemImage: "bell.badge") }
        case .denied:
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: { Label("Open System Settings", systemImage: "gear") }
        default:
            EmptyView()
        }
    }

    private func reminderLeadTimeRow(_ days: Int) -> some View {
        let isSelected = preferences.reminderLeadTimes.contains(days)
        return Button {
            if isSelected {
                if preferences.reminderLeadTimes.count > 1 { preferences.reminderLeadTimes.remove(days) }
            } else {
                preferences.reminderLeadTimes.insert(days)
            }
        } label: {
            HStack {
                Text(leadTimeTitle(days))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var aboutSettingsSection: some View {
        Section("About") {
            LabeledContent("App", value: "Touch Point")
            LabeledContent("Version", value: appVersion)
        }
    }

    private var cloudSettingsSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: cloudStatusIcon).foregroundStyle(cloudStatusColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cloudKit.state.title).font(.subheadline.weight(.semibold))
                    Text(cloudKit.state.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { synchronizeCloudKit() } label: {
                Label(isSynchronizingCloudKit ? "Syncing…" : "Sync iCloud now", systemImage: "arrow.triangle.2.circlepath.icloud")
            }
            .disabled(isSynchronizingCloudKit)
        } header: {
            Text("Private iCloud backup")
        } footer: {
            Text("Touch Point keeps working locally without an account or network. Your complete private snapshot is used for recovery on another device; it is not shared with other people.")
        }
    }

    private var archiveSettingsSection: some View {
        Section {
            Button {
                do {
                    exportDocument = try TouchPointArchiveDocument(data: store.exportArchive())
                    showingArchiveExporter = true
                }
                catch { archiveError = error.localizedDescription }
            } label: { Label("Export all Touch Point data", systemImage: "square.and.arrow.up") }
            Button { showingArchiveImporter = true } label: {
                Label("Replace with an archive…", systemImage: "square.and.arrow.down")
            }
            if store.recoverableSnapshotData() != nil {
                Button(role: .destructive) { showingRecoveryConfirmation = true } label: {
                    Label("Restore recovered local backup", systemImage: "arrow.uturn.backward.circle")
                }
            }
        } header: {
            Text("Local archive")
        } footer: {
            Text("An archive includes people, dates, greetings, templates, revisions, and usage history. Replacing data is validated before it is saved.")
        }
    }

    private var templateLibrarySettingsSection: some View {
        Section {
            Button { showingTemplateImporter = true } label: {
                Label("Import library", systemImage: "square.and.arrow.down")
            }
            Button {
                templateExportDocument = TemplateLibraryDocument(
                    templates: store.templates,
                    groups: store.templateGroups
                )
                showingTemplateExporter = true
            } label: {
                Label("Export library", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Template library")
        } footer: {
            Text("Import adds templates and collections to the current library. Export saves the template library without people, greetings, or usage history.")
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
                let result = try await LocalNotificationScheduler.synchronize(events: store.events, people: store.people, settings: reminderSettings)
                preferences.notificationSyncError = result.droppedCount > 0
                    ? "Only the nearest 64 reminders are scheduled. Touch Point will add later reminders as dates get closer."
                    : nil
            } catch {
                notificationError = error.localizedDescription
                preferences.notificationSyncError = error.localizedDescription
            }
        }
    }

    private func synchronizeNotificationsNow() {
        isSynchronizingNotifications = true
        Task {
            defer { isSynchronizingNotifications = false }
            do {
                let result = try await LocalNotificationScheduler.synchronize(
                    events: store.events,
                    people: store.people,
                    settings: reminderSettings
                )
                preferences.notificationSyncError = result.droppedCount > 0
                    ? "Only the nearest 64 reminders are scheduled. Touch Point will add later reminders as dates get closer."
                    : nil
            } catch {
                preferences.notificationSyncError = error.localizedDescription
            }
        }
    }

    private var reminderSettings: LocalReminderSettings {
        LocalReminderSettings(
            leadTimesDays: preferences.reminderLeadTimes,
            hour: preferences.reminderHour,
            minute: preferences.reminderMinute,
            hidesNames: preferences.hideReminderNames
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: preferences.reminderHour, minute: preferences.reminderMinute, second: 0, of: .now) ?? .now
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                preferences.reminderHour = components.hour ?? 9
                preferences.reminderMinute = components.minute ?? 0
            }
        )
    }

    private func leadTimeTitle(_ days: Int) -> String {
        switch days {
        case 0: "On the day"
        case 1: "1 day before"
        default: "\(days) days before"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await LocalNotificationScheduler.authorizationStatus()
    }

    private var cloudStatusIcon: String {
        switch cloudKit.state {
        case .synced: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .error: "exclamationmark.icloud"
        default: "icloud"
        }
    }

    private var cloudStatusColor: Color {
        switch cloudKit.state {
        case .synced: .green
        case .error: .red
        case .syncing: .accentColor
        default: .secondary
        }
    }

    private func synchronizeCloudKit() {
        isSynchronizingCloudKit = true
        Task {
            defer { isSynchronizingCloudKit = false }
            do {
                let archive = try store.exportArchive()
                if let remote = await cloudKit.synchronize(
                    archiveData: archive,
                    localModifiedAt: store.lastModifiedAt,
                    hasLocalUserData: store.hasUserContent
                ) {
                    guard store.importArchive(remote, preservingModifiedAt: true) else {
                        cloudKit.resetLocalSyncMetadata()
                        archiveError = store.persistenceError ?? "The iCloud snapshot could not be restored."
                        return
                    }
                }
            } catch {
                archiveError = error.localizedDescription
            }
        }
    }

    private func importArchive(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard store.importArchive(data) else {
                archiveError = store.persistenceError ?? "This archive could not be imported."
                return
            }
        } catch {
            archiveError = error.localizedDescription
        }
    }

    private func importTemplateLibrary(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let payload = try JSONDecoder.templateLibrary.decode(
                TemplateLibraryPayload.self,
                from: Data(contentsOf: url)
            )
            var groupMap: [UUID: UUID] = [:]
            for imported in payload.groups where !imported.isArchived {
                let group = TemplateGroup(
                    name: imported.name,
                    iconSemantic: imported.iconSemantic,
                    iconID: imported.iconID,
                    colorToken: imported.colorToken,
                    sortOrder: store.templateGroups.count
                )
                groupMap[imported.id] = group.id
                store.addTemplateGroup(group)
            }
            for imported in payload.templates where !imported.isArchived {
                let template = GreetingTemplate(
                    title: imported.title,
                    occasions: imported.occasions,
                    body: imported.body,
                    isFavorite: imported.isFavorite,
                    iconSemantic: imported.iconSemantic,
                    iconID: imported.iconID,
                    colorToken: imported.colorToken,
                    groupID: imported.groupID.flatMap { groupMap[$0] },
                    relationships: imported.relationships,
                    channels: imported.channels,
                    languages: imported.languages,
                    emailSubject: imported.emailSubject,
                    isDefault: imported.isDefault
                )
                store.addTemplate(template)
                if template.isDefault {
                    _ = store.setTemplateDefault(id: template.id)
                }
            }
        } catch {
            templateTransferError = "Could not import this library. \(error.localizedDescription)"
        }
    }

    private func restoreRecoveredSnapshot() {
        guard !store.restoreCorruptSnapshot() else { return }
        archiveError = store.persistenceError ?? "The recovered local backup could not be restored."
    }
}

private struct OccasionGroupsSettingsView: View {
    @Environment(AppPreferences.self) private var preferences

    private var configurableCategories: [OccasionCategory] {
        OccasionCategory.allCases.filter { $0 != .personal }
    }

    var body: some View {
        List {
            Section {
                ForEach(configurableCategories) { category in
                    Toggle(isOn: Binding(
                        get: { !preferences.disabledOccasionCategories.contains(category) },
                        set: { isEnabled in
                            if isEnabled {
                                preferences.disabledOccasionCategories.remove(category)
                            } else {
                                preferences.disabledOccasionCategories.insert(category)
                            }
                        }
                    )) {
                        Text(category.title)
                    }
                }
            } footer: {
                Text("Personal moments is always enabled. Disabled groups are hidden from occasion selection and unplanned suggestions.")
            }
        }
        .navigationTitle("Occasion groups")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TemplateLibraryPayload {
    let version: Int
    let templates: [GreetingTemplate]
    let groups: [TemplateGroup]
}

nonisolated extension TemplateLibraryPayload: Codable {}

private struct TemplateLibraryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var payload: TemplateLibraryPayload

    init(templates: [GreetingTemplate] = [], groups: [TemplateGroup] = []) {
        payload = TemplateLibraryPayload(version: 1, templates: templates, groups: groups)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        payload = try JSONDecoder.templateLibrary.decode(TemplateLibraryPayload.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(payload))
    }
}

private extension JSONDecoder {
    static var templateLibrary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct TouchPointArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
