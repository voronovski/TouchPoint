import SwiftUI
import UniformTypeIdentifiers

struct TemplatesView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var query = ""
    @State private var scope: TemplateScope = .all
    @State private var editingTemplate: GreetingTemplate?
    @State private var showingNewTemplate = false
    @State private var showingGroups = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = TemplateLibraryDocument()
    @State private var transferError: String?
    @State private var templatePendingDeletion: GreetingTemplate?

    private var visibleTemplates: [GreetingTemplate] {
        store.templates
            .filter { template in
                switch scope {
                case .all: !template.isArchived
                case .favorites: !template.isArchived && template.isFavorite
                case .recent: !template.isArchived && template.lastUsedAt != nil
                case .ungrouped: !template.isArchived && template.groupID == nil
                case .archived: template.isArchived
                case .group(let id): !template.isArchived && template.groupID == id
                }
            }
            .filter { template in
                guard !query.isEmpty else { return true }
                let searchable = [
                    template.title, template.body, template.emailSubject ?? "",
                    template.occasions.map(\.title).joined(separator: " "),
                    template.relationships.map(\.title).joined(separator: " "),
                    template.channels.map(\.title).joined(separator: " "),
                    template.languages.joined(separator: " ")
                ].joined(separator: " ")
                return searchable.localizedCaseInsensitiveContains(query)
            }
            .sorted(by: templateSort)
    }

    var body: some View {
        NavigationStack {
            List {
                if let persistenceError = store.persistenceError {
                    Section {
                        Label(persistenceError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section { collectionMenu }

                if !visibleTemplates.isEmpty {
                    Section(scope.title(in: store)) {
                        ForEach(visibleTemplates) { template in
                            TemplateRow(template: template, group: group(for: template))
                                .contentShape(Rectangle())
                                .onTapGesture { editingTemplate = template }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        store.toggleTemplateFavorite(id: template.id)
                                    } label: {
                                        Label(template.isFavorite ? "Unfavorite" : "Favorite", systemImage: template.isFavorite ? "star.slash" : "star")
                                    }
                                    .tint(TouchPointColor.amber)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if template.isArchived {
                                        Button {
                                            store.archiveTemplate(id: template.id, archived: false)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.accentColor)
                                    } else {
                                        Button {
                                            _ = store.duplicateTemplate(template)
                                        } label: {
                                            Label("Duplicate", systemImage: "plus.square.on.square")
                                        }
                                        .tint(.accentColor)

                                        Button(role: .destructive) {
                                            if template.isBuiltIn {
                                                store.archiveTemplate(id: template.id)
                                            } else {
                                                templatePendingDeletion = template
                                            }
                                        } label: {
                                            Label(template.isBuiltIn ? "Archive" : "Delete", systemImage: template.isBuiltIn ? "archivebox" : "trash")
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button { editingTemplate = template } label: { Label("Edit", systemImage: "pencil") }
                                    Button { _ = store.duplicateTemplate(template) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                    Button { store.toggleTemplateFavorite(id: template.id) } label: {
                                        Label(template.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
                                    }
                                }
                        }
                    }
                }
            }
            .overlay {
                if visibleTemplates.isEmpty && store.persistenceError == nil {
                    ContentUnavailableView {
                        Label(query.isEmpty ? "No templates here" : "No matching templates", systemImage: "rectangle.stack.badge.plus")
                    } description: {
                        Text(query.isEmpty ? "Create a reusable message or choose another collection." : "Try another search or collection.")
                    } actions: {
                        if query.isEmpty && scope != .archived {
                            Button("Create template") { showingNewTemplate = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Name, message, audience, or language")
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingNewTemplate = true } label: { Label("New template", systemImage: "doc.badge.plus") }
                        Button { showingGroups = true } label: { Label("Manage collections", systemImage: "folder") }
                        Divider()
                        Button { showingImporter = true } label: { Label("Import library", systemImage: "square.and.arrow.down") }
                        Button {
                            exportDocument = TemplateLibraryDocument(templates: store.templates, groups: store.templateGroups)
                            showingExporter = true
                        } label: {
                            Label("Export library", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                TemplateEditorView(template: nil, defaultOccasion: preferences.focus.occasionPriority[0])
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template, defaultOccasion: template.occasion)
            }
            .sheet(isPresented: $showingGroups) { TemplateGroupsView() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                importLibrary(result)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "TouchPoint Templates"
            ) { result in
                if case .failure(let error) = result { transferError = error.localizedDescription }
            }
            .alert("Template library", isPresented: Binding(
                get: { transferError != nil },
                set: { if !$0 { transferError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(transferError ?? "")
            }
            .confirmationDialog(
                "Delete template?",
                isPresented: Binding(
                    get: { templatePendingDeletion != nil },
                    set: { if !$0 { templatePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let templatePendingDeletion else { return }
                    _ = store.deleteTemplate(id: templatePendingDeletion.id)
                    self.templatePendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { templatePendingDeletion = nil }
            } message: {
                Text("Existing scheduled greetings keep their current message.")
            }
        }
    }

    private var collectionMenu: some View {
        Menu {
            Button { scope = .all } label: { menuLabel("All templates", selected: scope == .all) }
            Button { scope = .favorites } label: { menuLabel("Favorites", selected: scope == .favorites) }
            Button { scope = .recent } label: { menuLabel("Recently used", selected: scope == .recent) }
            Button { scope = .ungrouped } label: { menuLabel("Ungrouped", selected: scope == .ungrouped) }
            Button { scope = .archived } label: { menuLabel("Archived", selected: scope == .archived) }
            if !activeGroups.isEmpty {
                Divider()
                ForEach(activeGroups) { group in
                    Button { scope = .group(group.id) } label: { menuLabel(group.name, selected: scope == .group(group.id)) }
                }
            }
        } label: {
            HStack {
                Label(scope.title(in: store), systemImage: scope.icon(in: store))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func menuLabel(_ title: String, selected: Bool) -> some View {
        if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private var activeGroups: [TemplateGroup] {
        store.templateGroups.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func group(for template: GreetingTemplate) -> TemplateGroup? {
        guard let groupID = template.groupID else { return nil }
        return store.templateGroups.first { $0.id == groupID }
    }

    private func templateSort(_ lhs: GreetingTemplate, _ rhs: GreetingTemplate) -> Bool {
        if scope == .recent, lhs.lastUsedAt != rhs.lastUsedAt {
            return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
        }
        if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private func importLibrary(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let payload = try JSONDecoder.touchPoint.decode(TemplateLibraryPayload.self, from: Data(contentsOf: url))
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
            transferError = "Could not import this library. \(error.localizedDescription)"
        }
    }
}

private enum TemplateScope: Hashable {
    case all, favorites, recent, ungrouped, archived
    case group(UUID)

    func title(in store: AppStore) -> String {
        switch self {
        case .all: "All templates"
        case .favorites: "Favorites"
        case .recent: "Recently used"
        case .ungrouped: "Ungrouped"
        case .archived: "Archived"
        case .group(let id): store.templateGroups.first(where: { $0.id == id })?.name ?? "Collection"
        }
    }

    func icon(in store: AppStore) -> String {
        switch self {
        case .all: "rectangle.stack"
        case .favorites: "star"
        case .recent: "clock.arrow.circlepath"
        case .ungrouped: "tray"
        case .archived: "archivebox"
        case .group(let id): store.templateGroups.first(where: { $0.id == id })?.iconID ?? "folder"
        }
    }
}

private struct TemplateRow: View {
    let template: GreetingTemplate
    let group: TemplateGroup?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemImage: template.iconID, tint: template.colorToken.templateColor)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(template.title).font(.subheadline.weight(.semibold))
                    if template.isDefault {
                        Text("DEFAULT").font(.caption2.weight(.bold)).foregroundStyle(.accent)
                    }
                    if template.isFavorite {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(TouchPointColor.amber)
                    }
                }
                Text(template.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(metadata).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var metadata: String {
        var parts = [template.occasions.map(\.title).joined(separator: ", ")]
        if let group { parts.append(group.name) }
        if !template.languages.isEmpty { parts.append(template.languages.joined(separator: ", ")) }
        if !template.channels.isEmpty { parts.append(template.channels.map(\.title).joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

private struct TemplateEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GreetingTemplate
    @State private var showingGenerator = false
    private let isEditing: Bool

    init(template: GreetingTemplate?, defaultOccasion: Occasion) {
        isEditing = template != nil
        _draft = State(initialValue: template ?? GreetingTemplate(title: "", occasion: defaultOccasion, message: ""))
    }

    private var canSave: Bool { draft.validationErrors.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Template name", text: $draft.title)
                    Picker("Collection", selection: $draft.groupID) {
                        Text("No collection").tag(UUID?.none)
                        ForEach(activeGroups) { group in
                            Label(group.name, systemImage: group.iconID).tag(Optional(group.id))
                        }
                    }
                    Picker("Icon", selection: $draft.iconID) {
                        ForEach(TemplateAppearance.icons, id: \.id) { option in
                            Label(option.title, systemImage: option.id).tag(option.id)
                        }
                    }
                    Picker("Color", selection: $draft.colorToken) {
                        ForEach(TemplateAppearance.colors, id: \.id) { option in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(option.id.templateColor)
                                Text(option.title)
                            }
                            .tag(option.id)
                        }
                    }
                }

                Section("Context") {
                    multiValueMenu(title: "Occasions", summary: draft.occasions.map(\.title).joined(separator: ", ")) {
                        ForEach(Occasion.allCases) { occasion in
                            Button { toggleOccasion(occasion) } label: {
                                Label(occasion.title, systemImage: draft.occasions.contains(occasion) ? "checkmark" : occasion.icon)
                            }
                        }
                    }
                    multiValueMenu(title: "Audience", summary: draft.relationships.isEmpty ? "Any relationship" : draft.relationships.map(\.title).joined(separator: ", ")) {
                        Button("Any relationship") { draft.relationships = [] }
                        Divider()
                        ForEach(Relationship.allCases) { relationship in
                            Button { toggle(relationship, in: &draft.relationships) } label: {
                                Label(relationship.title, systemImage: draft.relationships.contains(relationship) ? "checkmark" : "person")
                            }
                        }
                    }
                    multiValueMenu(title: "Channels", summary: draft.channels.isEmpty ? "Any channel" : draft.channels.map(\.title).joined(separator: ", ")) {
                        Button("Any channel") { draft.channels = [] }
                        Divider()
                        ForEach(ContactMethod.allCases) { channel in
                            Button { toggle(channel, in: &draft.channels) } label: {
                                Label(channel.title, systemImage: draft.channels.contains(channel) ? "checkmark" : channel.icon)
                            }
                        }
                    }
                    Picker("Language", selection: languageBinding) {
                        Text("Any language").tag("")
                        ForEach(TemplateAppearance.languages, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    if draft.channels.isEmpty || draft.channels.contains(.email) {
                        TextField("Email subject (optional)", text: emailSubjectBinding)
                    }
                    TextEditor(text: $draft.body).frame(minHeight: 150)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(GreetingTemplate.supportedTokens.sorted(), id: \.self) { token in
                                Button("{{\(token)}}") { appendToken(token) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                    Button { showingGenerator = true } label: {
                        Label("Generate with Apple Intelligence", systemImage: "apple.intelligence")
                    }
                } header: {
                    Text("Message")
                } footer: {
                    Text("Insert variables with the buttons above. Generation happens on device when Apple Intelligence is available.")
                }

                Section("Preview") {
                    if let subject = previewSubject {
                        LabeledContent("Subject", value: subject)
                    }
                    Text(previewBody).frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(draft.body.isEmpty ? .secondary : .primary)
                }

                if !draft.validationErrors.isEmpty {
                    Section("Needs attention") {
                        ForEach(draft.validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        }
                    }
                }

                Section("Library") {
                    Toggle("Favorite", isOn: $draft.isFavorite)
                    Toggle("Default for this context", isOn: $draft.isDefault)
                    if draft.usageCount > 0 { LabeledContent("Used", value: draft.usageCount.formatted()) }
                }
            }
            .navigationTitle(isEditing ? "Edit template" : "New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingGenerator) {
                AppleGreetingGeneratorSheet(context: generationContext) { draft.body = $0 }
            }
        }
    }

    private var activeGroups: [TemplateGroup] {
        store.templateGroups.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var languageBinding: Binding<String> {
        Binding(get: { draft.languages.first ?? "" }, set: { draft.languages = $0.isEmpty ? [] : [$0] })
    }
    private var emailSubjectBinding: Binding<String> {
        Binding(get: { draft.emailSubject ?? "" }, set: { draft.emailSubject = $0.isEmpty ? nil : $0 })
    }
    private var previewPerson: Person {
        store.people.first(where: { draft.relationships.isEmpty || draft.relationships.contains($0.relationship) })
            ?? Person(name: "Alex Morgan", organization: "Northstar", relationship: draft.relationships.first ?? .friend)
    }
    private var previewBody: String {
        guard !draft.body.isEmpty else { return "Your personalized preview will appear here." }
        return store.renderedBody(for: draft, person: previewPerson, occasion: draft.occasion)
    }
    private var previewSubject: String? {
        store.renderedEmailSubject(for: draft, person: previewPerson, occasion: draft.occasion)
    }
    private var generationContext: GreetingGenerationContext {
        GreetingGenerationContext(
            occasion: draft.occasions.map(\.title).joined(separator: ", "),
            relationship: draft.relationships.isEmpty ? "Any relationship" : draft.relationships.map(\.title).joined(separator: ", "),
            channel: draft.channels.isEmpty ? "Any channel" : draft.channels.map(\.title).joined(separator: ", "),
            language: draft.languages.first ?? "English",
            recipientName: nil,
            usesNamePlaceholder: true
        )
    }

    @ViewBuilder
    private func multiValueMenu<Content: View>(title: String, summary: String, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent(title) { Menu(summary, content: content).multilineTextAlignment(.trailing) }
    }
    private func toggleOccasion(_ occasion: Occasion) {
        if draft.occasions.contains(occasion) {
            guard draft.occasions.count > 1 else { return }
            draft.occasions.removeAll { $0 == occasion }
        } else { draft.occasions.append(occasion) }
    }
    private func toggle<T: Equatable>(_ item: T, in items: inout [T]) {
        if let index = items.firstIndex(of: item) { items.remove(at: index) } else { items.append(item) }
    }
    private func appendToken(_ token: String) {
        if !draft.body.isEmpty && !draft.body.hasSuffix(" ") { draft.body.append(" ") }
        draft.body.append("{{\(token)}}")
    }
    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.emailSubject = draft.emailSubject?.trimmingCharacters(in: .whitespacesAndNewlines)
        if isEditing { store.updateTemplate(draft) } else { store.addTemplate(draft) }
        if draft.isDefault { _ = store.setTemplateDefault(id: draft.id) }
        dismiss()
    }
}

private struct TemplateGroupsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingGroup: TemplateGroup?
    @State private var showingNewGroup = false

    private var groups: [TemplateGroup] {
        store.templateGroups.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Button { editingGroup = group } label: {
                        HStack {
                            IconTile(systemImage: group.iconID, tint: group.colorToken.templateColor)
                            Text(group.name).foregroundStyle(.primary)
                            Spacer()
                            Text(store.templates(in: group.id).count.formatted()).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { _ = store.deleteTemplateGroup(id: groups[index].id) }
                }
                .onMove { source, destination in
                    var reordered = groups
                    reordered.move(fromOffsets: source, toOffset: destination)
                    _ = store.reorderTemplateGroups(ids: reordered.map(\.id))
                }
            }
            .overlay {
                if groups.isEmpty {
                    ContentUnavailableView("No collections", systemImage: "folder.badge.plus", description: Text("Collections keep related templates together."))
                }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button { showingNewGroup = true } label: { Label("New collection", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingNewGroup) { TemplateGroupEditorView(group: nil) }
            .sheet(item: $editingGroup) { TemplateGroupEditorView(group: $0) }
        }
    }
}

private struct TemplateGroupEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TemplateGroup
    private let isEditing: Bool

    init(group: TemplateGroup?) {
        isEditing = group != nil
        _draft = State(initialValue: group ?? TemplateGroup(name: "", sortOrder: Int.max))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Collection") {
                    TextField("Name", text: $draft.name)
                    Picker("Icon", selection: $draft.iconID) {
                        ForEach(TemplateAppearance.groupIcons, id: \.id) { option in
                            Label(option.title, systemImage: option.id).tag(option.id)
                        }
                    }
                    Picker("Color", selection: $draft.colorToken) {
                        ForEach(TemplateAppearance.colors, id: \.id) { option in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(option.id.templateColor)
                                Text(option.title)
                            }
                            .tag(option.id)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit collection" : "New collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isEditing { store.updateTemplateGroup(draft) } else { store.addTemplateGroup(draft) }
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum TemplateAppearance {
    struct Option { let id: String; let title: String }
    static let icons = [
        Option(id: "text.quote", title: "Message"), Option(id: "birthday.cake", title: "Birthday"),
        Option(id: "heart", title: "Heart"), Option(id: "house", title: "Home"),
        Option(id: "gift", title: "Gift"), Option(id: "hands.sparkles", title: "Appreciation"),
        Option(id: "person.2", title: "People"), Option(id: "star", title: "Favorite"),
        Option(id: "sparkles", title: "Special"), Option(id: "message", title: "Text"),
        Option(id: "envelope", title: "Email"), Option(id: "leaf", title: "Seasonal")
    ]
    static let groupIcons = [
        Option(id: "folder", title: "Folder"), Option(id: "person.2", title: "People"),
        Option(id: "briefcase", title: "Work"), Option(id: "heart", title: "Personal"),
        Option(id: "gift", title: "Holidays"), Option(id: "star", title: "VIP")
    ]
    static let colors = [
        Option(id: "blue", title: "Blue"), Option(id: "coral", title: "Coral"),
        Option(id: "rose", title: "Rose"), Option(id: "amber", title: "Amber"),
        Option(id: "forest", title: "Forest"), Option(id: "teal", title: "Teal")
    ]
    static let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Russian", "Ukrainian"]
}

private extension String {
    var templateColor: Color {
        switch self {
        case "coral": TouchPointColor.coral
        case "rose": TouchPointColor.rose
        case "amber": TouchPointColor.amber
        case "forest": TouchPointColor.forest
        case "teal": TouchPointColor.teal
        default: .accentColor
        }
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
        payload = try JSONDecoder.touchPoint.decode(TemplateLibraryPayload.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(payload))
    }
}

private extension JSONDecoder {
    static var touchPoint: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
