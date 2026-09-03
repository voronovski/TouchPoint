import SwiftUI
import UniformTypeIdentifiers

struct TemplatesView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var query = ""
    @State private var scope: TemplateScope = .all
    @State private var occasionFilter: Occasion?
    @State private var relationshipFilter: Relationship?
    @State private var channelFilter: ContactMethod?
    @State private var languageFilter: String?
    @State private var sort: TemplateSort = .recommended
    @State private var editingTemplate: GreetingTemplate?
    @State private var showingNewTemplate = false
    @State private var showingGroups = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = TemplateLibraryDocument()
    @State private var transferError: String?
    @State private var templatePendingDeletion: GreetingTemplate?

    private var collectionTemplates: [GreetingTemplate] {
        store.templates
            .filter { template in
                switch scope {
                case .all: !template.isArchived
                case .favorites: !template.isArchived && template.isFavorite
                case .recent: !template.isArchived && template.lastUsedAt != nil
                case .ungrouped: !template.isArchived && template.groupID == nil
                case .archived: template.isArchived
                case .group(let id): !template.isArchived && template.groupID == id
                case .mostUsed: !template.isArchived && template.usageCount > 0
                case .missingDefault: !template.isArchived && isMissingDefault(template)
                }
            }
    }

    private var visibleTemplates: [GreetingTemplate] {
        collectionTemplates
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
            .filter { template in
                guard let occasionFilter else { return true }
                return template.occasions.contains(occasionFilter)
            }
            .filter { template in
                guard let relationshipFilter else { return true }
                return template.relationships.isEmpty || template.relationships.contains(relationshipFilter)
            }
            .filter { template in
                guard let channelFilter else { return true }
                return template.channels.isEmpty || template.channels.contains(channelFilter)
            }
            .filter { template in
                guard let languageFilter, !languageFilter.isEmpty else { return true }
                return template.languages.isEmpty || template.languages.contains {
                    $0.localizedCaseInsensitiveCompare(languageFilter) == .orderedSame
                }
            }
            .sorted(by: templateSort)
    }

    private var hasActiveFilters: Bool {
        !query.isEmpty || occasionFilter != nil || relationshipFilter != nil || channelFilter != nil || languageFilter != nil
    }

    private var hasMetadataFilters: Bool {
        occasionFilter != nil || relationshipFilter != nil || channelFilter != nil || languageFilter != nil
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

                Section {
                    filterControls
                } header: {
                    Text("Filter templates")
                }

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
                                            if template.isBuiltIn || template.isLocked {
                                                store.archiveTemplate(id: template.id)
                                            } else {
                                                templatePendingDeletion = template
                                            }
                                        } label: {
                                            let archivesInsteadOfDeleting = template.isBuiltIn || template.isLocked
                                            Label(
                                                archivesInsteadOfDeleting ? "Archive" : "Delete",
                                                systemImage: archivesInsteadOfDeleting ? "archivebox" : "trash"
                                            )
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button { editingTemplate = template } label: {
                                        Label(template.isLocked ? "View details" : "Edit", systemImage: template.isLocked ? "doc.text.magnifyingglass" : "pencil")
                                    }
                                    Button { _ = store.duplicateTemplate(template) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                    Button { store.toggleTemplateFavorite(id: template.id) } label: {
                                        Label(template.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
                                    }
                                    Divider()
                                    if template.isApproved {
                                        if !template.isBuiltIn {
                                            Button { _ = store.setTemplateApproval(id: template.id, approved: false) } label: {
                                                Label("Remove approval", systemImage: "checkmark.seal.slash")
                                            }
                                        }
                                    } else {
                                        Button { _ = store.setTemplateApproval(id: template.id, approved: true) } label: {
                                            Label("Approve", systemImage: "checkmark.seal")
                                        }
                                    }
                                    if template.isLocked {
                                        if !template.isBuiltIn {
                                            Button { _ = store.setTemplateLock(id: template.id, locked: false) } label: {
                                                Label("Unlock", systemImage: "lock.open")
                                            }
                                        }
                                    } else {
                                        Button { _ = store.setTemplateLock(id: template.id, locked: true) } label: {
                                            Label("Lock", systemImage: "lock")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .overlay {
                if visibleTemplates.isEmpty && store.persistenceError == nil {
                    ContentUnavailableView {
                        Label(emptyStateTitle, systemImage: "rectangle.stack.badge.plus")
                    } description: {
                        Text(emptyStateDescription)
                    } actions: {
                        if hasActiveFilters {
                            Button("Clear filters") { clearFilters() }
                                .buttonStyle(.bordered)
                        } else if scope != .archived && scope != .mostUsed {
                            Button("Create template") { showingNewTemplate = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Name, message, occasion, audience, channel, or language")
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort templates", selection: $sort) {
                            ForEach(TemplateSort.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Label(sort.title, systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort templates")
                    .accessibilityValue(sort.title)
                }
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
            Divider()
            Text("Smart scopes")
            Button { scope = .mostUsed } label: { menuLabel("Most used", selected: scope == .mostUsed) }
            Button { scope = .missingDefault } label: { menuLabel("Missing default", selected: scope == .missingDefault) }
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Template collection")
            .accessibilityValue(scope.title(in: store))
        }
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            filterMenu(
                title: "Occasion",
                value: occasionFilter?.title ?? "Any occasion",
                icon: "calendar"
            ) {
                Button { occasionFilter = nil } label: { menuLabel("Any occasion", selected: occasionFilter == nil) }
                Divider()
                ForEach(Occasion.allCases) { occasion in
                    Button { occasionFilter = occasion } label: {
                        menuLabel(occasion.title, selected: occasionFilter == occasion)
                    }
                }
            }

            filterMenu(
                title: "Audience",
                value: relationshipFilter?.title ?? "Any relationship",
                icon: "person.2"
            ) {
                Button { relationshipFilter = nil } label: {
                    menuLabel("Any relationship", selected: relationshipFilter == nil)
                }
                Divider()
                ForEach(Relationship.allCases) { relationship in
                    Button { relationshipFilter = relationship } label: {
                        menuLabel(relationship.title, selected: relationshipFilter == relationship)
                    }
                }
            }

            filterMenu(
                title: "Channel",
                value: channelFilter?.title ?? "Any channel",
                icon: "arrow.up.right"
            ) {
                Button { channelFilter = nil } label: {
                    menuLabel("Any channel", selected: channelFilter == nil)
                }
                Divider()
                ForEach(ContactMethod.allCases) { channel in
                    Button { channelFilter = channel } label: {
                        menuLabel(channel.title, selected: channelFilter == channel)
                    }
                }
            }

            filterMenu(
                title: "Language",
                value: languageFilter ?? "Any language",
                icon: "character.book.closed"
            ) {
                Button { languageFilter = nil } label: {
                    menuLabel("Any language", selected: languageFilter == nil)
                }
                Divider()
                ForEach(TemplateAppearance.languages, id: \.self) { language in
                    Button { languageFilter = language } label: {
                        menuLabel(language, selected: languageFilter == language)
                    }
                }
            }

            if hasMetadataFilters || !query.isEmpty {
                Button("Clear filters", action: clearFilters)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint("Removes the search and all template filters")
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func filterMenu<Content: View>(
        title: String,
        value: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LabeledContent {
            Menu {
                content()
            } label: {
                Text(value)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityLabel(title)
            .accessibilityValue(value)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private var emptyStateTitle: String {
        if hasActiveFilters { return "No matching templates" }
        switch scope {
        case .mostUsed: return "No used templates yet"
        case .missingDefault: return "Every context has a default"
        default: return "No templates here"
        }
    }

    private var emptyStateDescription: String {
        if hasActiveFilters { return "Try removing a filter or changing your search." }
        switch scope {
        case .mostUsed: return "Templates will appear here after you use them."
        case .missingDefault: return "Every active template context has at least one default."
        default: return "Create a reusable message or choose another collection."
        }
    }

    private func clearFilters() {
        query = ""
        occasionFilter = nil
        relationshipFilter = nil
        channelFilter = nil
        languageFilter = nil
    }

    private func isMissingDefault(_ template: GreetingTemplate) -> Bool {
        let relationships = Set(template.relationships)
        let channels = Set(template.channels)
        let languages = Set(template.languages.map { $0.lowercased() })

        return template.occasions.contains { occasion in
            !store.templates.contains { candidate in
                !candidate.isArchived
                    && candidate.isDefault
                    && candidate.occasions.contains(occasion)
                    && Set(candidate.relationships) == relationships
                    && Set(candidate.channels) == channels
                    && Set(candidate.languages.map { $0.lowercased() }) == languages
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
        switch sort {
        case .recommended:
            // Preserve the established Recently used ordering while making the
            // smart Most used scope useful at a glance as well.
            if scope == .recent, lhs.lastUsedAt != rhs.lastUsedAt {
                return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
            if scope == .mostUsed, lhs.usageCount != rhs.usageCount {
                return lhs.usageCount > rhs.usageCount
            }
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        case .name:
            let comparison = lhs.title.localizedStandardCompare(rhs.title)
            if comparison != .orderedSame { return comparison == .orderedAscending }
        case .mostUsed:
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
            if lhs.lastUsedAt != rhs.lastUsedAt {
                return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        case .recentlyUpdated:
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        }
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
    case all, favorites, recent, ungrouped, archived, mostUsed, missingDefault
    case group(UUID)

    func title(in store: AppStore) -> String {
        switch self {
        case .all: "All templates"
        case .favorites: "Favorites"
        case .recent: "Recently used"
        case .ungrouped: "Ungrouped"
        case .archived: "Archived"
        case .group(let id): store.templateGroups.first(where: { $0.id == id })?.name ?? "Collection"
        case .mostUsed: "Most used"
        case .missingDefault: "Missing default"
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
        case .mostUsed: "chart.bar.fill"
        case .missingDefault: "checkmark.shield"
        }
    }
}

private enum TemplateSort: String, CaseIterable, Identifiable {
    case recommended
    case name
    case mostUsed
    case recentlyUpdated

    var id: Self { self }

    var title: String {
        switch self {
        case .recommended: "Recommended"
        case .name: "Name"
        case .mostUsed: "Most used"
        case .recentlyUpdated: "Recently updated"
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
                HStack(spacing: 5) {
                    TemplateStatusBadge(title: "Version \(template.revisionNumber)", systemImage: "clock.arrow.circlepath")
                    if template.isApproved {
                        TemplateStatusBadge(title: "Approved", systemImage: "checkmark.seal.fill")
                    }
                    if template.isLocked {
                        TemplateStatusBadge(title: "Locked", systemImage: "lock.fill")
                    }
                }
                Text(template.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(metadata).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(template.isLocked ? "Double-tap to view this locked template" : "Double-tap to edit this template")
    }

    private var metadata: String {
        var parts = [template.occasions.map(\.title).joined(separator: ", ")]
        if let group { parts.append(group.name) }
        if !template.languages.isEmpty { parts.append(template.languages.joined(separator: ", ")) }
        if !template.channels.isEmpty { parts.append(template.channels.map(\.title).joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

private struct TemplateStatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(title)
    }
}

private struct TemplateEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GreetingTemplate
    @State private var showingGenerator = false
    @State private var showingApprovalWarning = false
    @State private var showingSaveError = false
    @State private var saveError: String?
    @State private var duplicateForEditing: GreetingTemplate?
    @State private var selectedRevision: TemplateRevision?
    private let originalTemplate: GreetingTemplate?
    private let isEditing: Bool

    init(template: GreetingTemplate?, defaultOccasion: Occasion) {
        isEditing = template != nil
        originalTemplate = template
        _draft = State(initialValue: template ?? GreetingTemplate(title: "", occasion: defaultOccasion, message: ""))
    }

    private var canSave: Bool { draft.validationErrors.isEmpty }
    private var isReadOnly: Bool { isEditing && draft.isLocked }
    private var hasContentChanges: Bool {
        guard let originalTemplate else { return false }
        return TemplateContentSnapshot(template: originalTemplate) != TemplateContentSnapshot(template: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isReadOnly {
                    Section {
                        Label("This template is locked and read-only.", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                        Button {
                            duplicateForEditing = store.duplicateTemplate(draft)
                        } label: {
                            Label("Duplicate to edit", systemImage: "plus.square.on.square")
                        }
                    } footer: {
                        Text("The duplicate is an unlocked copy. Approval and locking are local controls on this device.")
                    }
                }

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
                .disabled(isReadOnly)

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
                .disabled(isReadOnly)

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
                .disabled(isReadOnly)

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
                }
                .disabled(isReadOnly)

                if isEditing {
                    governanceSection
                    usageSection
                    historySection
                }
            }
            .navigationTitle(isEditing ? "Edit template" : "New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { requestSave() }.disabled(!canSave || isReadOnly)
                }
            }
            .sheet(isPresented: $showingGenerator) {
                AppleGreetingGeneratorSheet(context: generationContext) { draft.body = $0 }
            }
            .sheet(item: $duplicateForEditing) { template in
                TemplateEditorView(template: template, defaultOccasion: template.occasion)
            }
            .sheet(item: $selectedRevision) { revision in
                TemplateRevisionPreviewView(template: draft, revision: revision) { restored in
                    draft = restored
                }
            }
            .alert("Could not save template", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { showingSaveError = false }
            } message: {
                Text(saveError ?? "The template could not be saved. It remains open so you can try again.")
            }
            .confirmationDialog("Remove local approval?", isPresented: $showingApprovalWarning, titleVisibility: .visible) {
                Button("Save and remove approval") { performSave() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Changing this approved template will remove its approval on this device and create a new version.")
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
    private var governanceSection: some View {
        Section("Governance") {
            Text("Approval and locking are local controls on this device, not team approval.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LabeledContent("Approval", value: draft.isApproved ? "Approved" : "Not approved")
            if draft.isApproved {
                if draft.isBuiltIn {
                    Label("Built-in approval cannot be removed.", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        setApproval(false)
                    } label: {
                        Label("Remove approval", systemImage: "checkmark.seal.slash")
                    }
                }
            } else {
                Button {
                    setApproval(true)
                } label: {
                    Label("Approve on this device", systemImage: "checkmark.seal")
                }
            }

            LabeledContent("Editing", value: draft.isLocked ? "Locked" : "Unlocked")
            if draft.isLocked {
                if draft.isBuiltIn {
                    Label("Built-in templates cannot be unlocked.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        unlockForEditing()
                    } label: {
                        Label("Unlock to edit", systemImage: "lock.open")
                    }
                }
            } else {
                Button {
                    lockTemplate()
                } label: {
                    Label("Lock template", systemImage: "lock")
                }
            }
        }
    }

    private var usageSection: some View {
        Section("Usage") {
            LabeledContent("Lifetime schedules", value: draft.usageCount.formatted())
            LabeledContent("Last used", value: lastUsedText)
            ForEach(TemplateUsageKind.allCases) { kind in
                LabeledContent(usageTitle(kind), value: usageCount(for: kind).formatted())
            }
        }
    }

    private var historySection: some View {
        Section {
            LabeledContent("Current version", value: "Version \(draft.revisionNumber)")
            LabeledContent("Last updated", value: draft.updatedAt.formatted(date: .abbreviated, time: .shortened))

            if revisions.isEmpty {
                Text("No earlier versions yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(revisions) { revision in
                    Button {
                        selectedRevision = revision
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Version \(revision.number)")
                                    .font(.subheadline.weight(.semibold))
                                Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("Version \(revision.number)")
                    .accessibilityValue(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityHint("Double-tap to preview this version")
                }
            }
        } header: {
            Text("History")
        } footer: {
            Text("Restoring a version creates a new version and keeps the existing history.")
        }
    }

    private var revisions: [TemplateRevision] {
        guard isEditing else { return [] }
        return store.templateRevisions(for: draft.id)
    }

    private var usageRecords: [TemplateUsageRecord] {
        guard isEditing else { return [] }
        return store.usageRecords(for: draft.id)
    }

    private var lastUsedText: String {
        guard let lastUsedAt = draft.lastUsedAt else { return "Never" }
        return lastUsedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func usageCount(for kind: TemplateUsageKind) -> Int {
        usageRecords.reduce(into: 0) { count, record in
            if record.kind == kind { count += 1 }
        }
    }

    private func usageTitle(_ kind: TemplateUsageKind) -> String {
        switch kind {
        case .scheduled: "Tracked schedules"
        case .composerOpened: "Composer opened"
        case .completed: "Completed"
        case .skipped: "Skipped"
        case .messageEdited: "Message edited"
        }
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
    private func requestSave() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.emailSubject = draft.emailSubject?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSave else { return }
        if isEditing && draft.isApproved && hasContentChanges {
            showingApprovalWarning = true
        } else {
            performSave()
        }
    }

    private func performSave() {
        if isEditing {
            guard store.updateTemplateResult(draft) else {
                saveError = "This template could not be saved. It may be locked or no longer available."
                showingSaveError = true
                return
            }
        } else {
            store.addTemplate(draft)
        }
        if draft.isDefault { _ = store.setTemplateDefault(id: draft.id) }
        dismiss()
    }

    private func setApproval(_ approved: Bool) {
        guard store.setTemplateApproval(id: draft.id, approved: approved) else { return }
        draft.isApproved = approved
        draft.approvedAt = approved ? .now : nil
    }

    private func unlockForEditing() {
        guard !draft.isBuiltIn else { return }
        guard store.setTemplateLock(id: draft.id, locked: false) else {
            saveError = "This template could not be unlocked."
            showingSaveError = true
            return
        }
        draft.isLocked = false
    }

    private func lockTemplate() {
        guard store.setTemplateLock(id: draft.id, locked: true) else {
            saveError = "This template could not be locked. It may no longer be available."
            showingSaveError = true
            return
        }
        draft.isLocked = true
    }
}

private struct TemplateRevisionPreviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let template: GreetingTemplate
    let revision: TemplateRevision
    let onRestored: (GreetingTemplate) -> Void
    @State private var showingApprovalWarning = false
    @State private var restoreError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Version") {
                    LabeledContent("Version", value: revision.number.formatted())
                    LabeledContent("Created", value: revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Title", value: revision.snapshot.title)
                }

                Section("Preview") {
                    Text(revision.snapshot.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    if !revision.snapshot.occasions.isEmpty {
                        LabeledContent("Occasions", value: revision.snapshot.occasions.map(\.title).joined(separator: ", "))
                    }
                    if !revision.snapshot.languages.isEmpty {
                        LabeledContent("Languages", value: revision.snapshot.languages.joined(separator: ", "))
                    }
                }

                Section {
                    if template.isLocked {
                        Label("Unlock the template before restoring a version.", systemImage: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Restore this version") {
                            requestRestore()
                        }
                    }
                } footer: {
                    Text("Restoring is additive: it creates a new current version and keeps this version in history.")
                }
            }
            .navigationTitle("Version \(revision.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove local approval?", isPresented: $showingApprovalWarning, titleVisibility: .visible) {
                Button("Restore and remove approval") { performRestore() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Restoring this version changes the approved template and removes its approval on this device.")
            }
            .alert("Could not restore version", isPresented: Binding(
                get: { restoreError != nil },
                set: { if !$0 { restoreError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreError ?? "The version could not be restored.")
            }
        }
    }

    private func requestRestore() {
        guard !template.isLocked else { return }
        if template.isApproved {
            showingApprovalWarning = true
        } else {
            performRestore()
        }
    }

    private func performRestore() {
        guard store.restoreTemplateRevision(templateID: template.id, revisionID: revision.id),
              let restored = store.templates.first(where: { $0.id == template.id }) else {
            restoreError = "This version could not be restored. The template may be locked or no longer available."
            return
        }
        onRestored(restored)
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
