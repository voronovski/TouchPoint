import SwiftUI

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
    @State private var showingFilters = false
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
                    template.languages.joined(separator: " "),
                    group(for: template)?.name ?? ""
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
        scope != .all || !query.isEmpty || occasionFilter != nil || relationshipFilter != nil || channelFilter != nil || languageFilter != nil
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

                Section { libraryControls }

                if !visibleTemplates.isEmpty {
                    Section(scope.title(in: store)) {
                        ForEach(visibleTemplates) { template in
                            Button {
                                editingTemplate = template
                            } label: {
                                TemplateRow(template: template, group: group(for: template))
                                    .contentShape(Rectangle())
                            }
                                .buttonStyle(.plain)
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingGroups = true } label: {
                        Label("Manage collections", systemImage: "folder")
                    }
                    Button { showingNewTemplate = true } label: {
                        Label("New template", systemImage: "doc.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                TemplateEditorView(
                    template: nil,
                    defaultOccasion: preferences.focus.occasionPriority[0],
                    defaultLanguage: preferences.preferredLanguage
                )
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(
                    template: template,
                    defaultOccasion: template.occasion,
                    defaultLanguage: preferences.preferredLanguage
                )
            }
            .sheet(isPresented: $showingGroups) { TemplateGroupsView() }
            .sheet(isPresented: $showingFilters) {
                TemplateFiltersSheet(
                    occasion: $occasionFilter,
                    relationship: $relationshipFilter,
                    channel: $channelFilter,
                    language: $languageFilter
                )
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

    private var libraryControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                collectionMenu
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 28)

                Button { showingFilters = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: metadataFilterCount == 0 ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                        Text("Filters")
                        if metadataFilterCount > 0 {
                            Text(metadataFilterCount.formatted())
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 5)
                                .frame(minHeight: 18)
                                .background(Color.accentColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Template filters")
                .accessibilityValue(metadataFilterCount == 0 ? "None" : "\(metadataFilterCount) active")

                Divider().frame(height: 28)

                sortMenu
            }

            if hasMetadataFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let occasionFilter {
                            filterChip(title: occasionFilter.title, systemImage: occasionFilter.icon) {
                                self.occasionFilter = nil
                            }
                        }
                        if let relationshipFilter {
                            filterChip(title: relationshipFilter.title, systemImage: "person.2") {
                                self.relationshipFilter = nil
                            }
                        }
                        if let channelFilter {
                            filterChip(title: channelFilter.title, systemImage: channelFilter.icon) {
                                self.channelFilter = nil
                            }
                        }
                        if let languageFilter {
                            filterChip(title: languageFilter, systemImage: "character.book.closed") {
                                self.languageFilter = nil
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
            HStack(spacing: 6) {
                Label(scope.title(in: store), systemImage: scope.icon(in: store))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel("Template collection")
        .accessibilityValue(scope.title(in: store))
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort templates", selection: $sort) {
                ForEach(TemplateSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .accessibilityLabel("Sort templates")
        .accessibilityValue(sort.title)
    }

    private var metadataFilterCount: Int {
        [occasionFilter != nil, relationshipFilter != nil, channelFilter != nil, languageFilter != nil]
            .filter { $0 }
            .count
    }

    private func filterChip(title: String, systemImage: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title).lineLimit(1)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
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
        scope = .all
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
        case .recommended: String(localized: "Recommended")
        case .name: String(localized: "Name")
        case .mostUsed: String(localized: "Most used")
        case .recentlyUpdated: String(localized: "Recently updated")
        }
    }
}

private struct TemplateFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var occasion: Occasion?
    @Binding var relationship: Relationship?
    @Binding var channel: ContactMethod?
    @Binding var language: String?
    @State private var showingOccasionPicker = false

    private var activeCount: Int {
        [occasion != nil, relationship != nil, channel != nil, language != nil]
            .filter { $0 }
            .count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showingOccasionPicker = true } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: "calendar", tint: .accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Occasion")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(occasion?.title ?? "Any occasion")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens a searchable occasion list")

                    Picker(selection: $relationship) {
                        Text("Any relationship").tag(Relationship?.none)
                        ForEach(Relationship.allCases) { option in
                            Text(option.title).tag(Optional(option))
                        }
                    } label: {
                        Label("Audience", systemImage: "person.2")
                    }

                    Picker(selection: $channel) {
                        Text("Any channel").tag(ContactMethod?.none)
                        ForEach(ContactMethod.allCases) { option in
                            Text(option.title).tag(Optional(option))
                        }
                    } label: {
                        Label("Channel", systemImage: "arrow.up.right")
                    }

                    Picker(selection: $language) {
                        Text("All languages").tag(String?.none)
                        ForEach(TouchPointLanguage.supported, id: \.self) { option in
                            Text(option).tag(Optional(option))
                        }
                    } label: {
                        Label("Language", systemImage: "character.book.closed")
                    }
                } footer: {
                    Text("Context filters combine with the selected collection and search.")
                }

                if activeCount > 0 {
                    Section {
                        Button(role: .destructive) {
                            occasion = nil
                            relationship = nil
                            channel = nil
                            language = nil
                        } label: {
                            Label(
                                "Clear context filters",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        }
                        .buttonStyle(TouchPointTertiaryButtonStyle(tint: .red))
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingOccasionPicker) {
                OccasionPickerSheet(
                    selection: occasion.map { [$0] } ?? [],
                    mode: .single,
                    allowsEmptySelection: true
                ) { selection in
                    occasion = selection.first
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct TemplateRow: View {
    let template: GreetingTemplate
    let group: TemplateGroup?

    var body: some View {
        HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
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
                HStack(spacing: 8) {
                    Label("Version \(template.revisionNumber)", systemImage: "clock.arrow.circlepath")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if template.isApproved {
                        TemplateStateIcon(title: "Approved", systemImage: "checkmark.seal.fill", tint: TouchPointColor.forest)
                    }
                    if template.isLocked {
                        TemplateStateIcon(title: "Locked", systemImage: "lock.fill", tint: .secondary)
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

private struct TemplateStateIcon: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
            .background(tint.opacity(0.12))
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .accessibilityLabel(title)
    }
}

private struct TemplateEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GreetingTemplate
    @State private var showingGenerator = false
    @State private var showingOccasionPicker = false
    @State private var showingApprovalWarning = false
    @State private var showingSaveError = false
    @State private var saveError: String?
    @State private var duplicateForEditing: GreetingTemplate?
    @State private var selectedRevision: TemplateRevision?
    private let originalTemplate: GreetingTemplate?
    private let isEditing: Bool

    init(template: GreetingTemplate?, defaultOccasion: Occasion, defaultLanguage: String) {
        isEditing = template != nil
        originalTemplate = template
        var initialDraft = template ?? GreetingTemplate(
            title: "",
            occasions: [defaultOccasion],
            body: "",
            languages: [TouchPointLanguage.resolved(defaultLanguage)]
        )
        if initialDraft.languages.isEmpty {
            initialDraft.languages = [TouchPointLanguage.resolved(defaultLanguage)]
        }
        _draft = State(initialValue: initialDraft)
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
                        .buttonStyle(TouchPointTertiaryButtonStyle())
                    } footer: {
                        Text("The duplicate is an unlocked copy. Approval and locking are local controls on this device.")
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        IconTile(systemImage: draft.iconID, tint: draft.colorToken.templateColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Untitled template") : draft.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(occasionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)

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
                    LabeledContent("Color") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(TemplateColorToken.allCases) { option in
                                    Button {
                                        draft.colorToken = option.rawValue
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(option.color)
                                                .frame(width: 26, height: 26)
                                            if draft.colorToken == option.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.caption2.weight(.black))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(option.title)
                                    .accessibilityAddTraits(draft.colorToken == option.rawValue ? .isSelected : [])
                                }
                            }
                        }
                    }
                } header: {
                    Text("Template")
                } footer: {
                    Text("The icon and color identify this template throughout the library.")
                }
                .disabled(isReadOnly)

                Section("Context") {
                    Button {
                        showingOccasionPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: "calendar", tint: .accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Occasions")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(occasionSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(draft.occasions.count.formatted())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens a searchable multi-select list")
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
                        ForEach(TouchPointLanguage.options(including: languageBinding.wrappedValue), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }
                .disabled(isReadOnly)

                Section {
                    if draft.channels.isEmpty || draft.channels.contains(.email) {
                        TextField("Email subject (optional)", text: emailSubjectBinding)
                    }
                    TextEditor(text: $draft.body).frame(minHeight: 150)
                    WrappingTokenLayout(horizontalSpacing: 8, verticalSpacing: 4) {
                        ForEach(GreetingTemplate.supportedTokens.sorted(), id: \.self) { token in
                            Button {
                                appendToken(token)
                            } label: {
                                Text(token)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Insert \(token) variable")
                        }
                    }
                    Button { showingGenerator = true } label: {
                        Label("Generate with Apple Intelligence", systemImage: "apple.intelligence")
                    }
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                    .disabled(!isGeneratorAvailable)
                } header: {
                    Text("Message")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insert variables with the buttons above.")
                        Text(generatorAvailabilityExplanation)
                    }
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
            .sheet(isPresented: $showingOccasionPicker) {
                OccasionPickerSheet(
                    selection: draft.occasions,
                    options: preferences.focus.occasionPriority,
                    mode: .multiple
                ) { draft.occasions = $0 }
            }
            .sheet(item: $duplicateForEditing) { template in
                TemplateEditorView(
                    template: template,
                    defaultOccasion: template.occasion,
                    defaultLanguage: preferences.preferredLanguage
                )
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
    private var occasionSummary: String {
        let titles = draft.occasions.map(\.title)
        guard titles.count > 2 else { return titles.joined(separator: ", ") }
        return "\(titles[0]), \(titles[1]) +\(titles.count - 2)"
    }
    private var languageBinding: Binding<String> {
        Binding(
            get: { draft.languages.first ?? preferences.preferredLanguage },
            set: { draft.languages = [TouchPointLanguage.resolved($0)] }
        )
    }
    private var emailSubjectBinding: Binding<String> {
        Binding(get: { draft.emailSubject ?? "" }, set: { draft.emailSubject = $0.isEmpty ? nil : $0 })
    }
    private var previewPerson: Person {
        store.people.first(where: { draft.relationships.isEmpty || draft.relationships.contains($0.relationship) })
            ?? Person(name: "Recipient", organization: "Organization", relationship: draft.relationships.first ?? .friend)
    }
    private var previewBody: String {
        guard !draft.body.isEmpty else { return "Your personalized preview will appear here." }
        return store.renderedBody(
            for: draft,
            person: previewPerson,
            occasion: draft.occasion,
            senderName: preferences.senderName
        )
    }
    private var previewSubject: String? {
        store.renderedEmailSubject(
            for: draft,
            person: previewPerson,
            occasion: draft.occasion,
            senderName: preferences.senderName
        )
    }
    private var generationContext: GreetingGenerationContext {
        GreetingGenerationContext(
            occasion: draft.occasions.map(\.title).joined(separator: ", "),
            relationship: draft.relationships.isEmpty ? "Any relationship" : draft.relationships.map(\.title).joined(separator: ", "),
            channel: draft.channels.isEmpty ? "Any channel" : draft.channels.map(\.title).joined(separator: ", "),
            language: draft.languages.first ?? preferences.preferredLanguage,
            recipientName: nil,
            usesNamePlaceholder: true,
            occasionDetails: draft.occasions
                .map { "\($0.title): \($0.generationContextDescription)" }
                .joined(separator: "\n"),
            senderName: preferences.senderName
        )
    }
    private var generatorStatus: AppleGreetingGeneratorStatus {
        AppleGreetingGenerator.status(for: generationContext.language)
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
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                }
            } else {
                Button {
                    setApproval(true)
                } label: {
                    Label("Approve on this device", systemImage: "checkmark.seal")
                }
                .buttonStyle(TouchPointTertiaryButtonStyle())
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
                    .buttonStyle(TouchPointTertiaryButtonStyle())
                }
            } else {
                Button {
                    lockTemplate()
                } label: {
                    Label("Lock template", systemImage: "lock")
                }
                .buttonStyle(TouchPointTertiaryButtonStyle())
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
                    .buttonStyle(.plain)
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
                        Button {
                            requestRestore()
                        } label: {
                            Label("Restore this version", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(TouchPointTertiaryButtonStyle())
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
    @State private var groupsPendingDeletion: [TemplateGroup] = []
    @State private var operationError: String?

    private var groups: [TemplateGroup] {
        store.templateGroups.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
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

                Section {
                    ForEach(groups) { group in
                        Button { editingGroup = group } label: {
                            CollectionRow(
                                group: group,
                                templateCount: store.templates(in: group.id).count
                            )
                        }
                        .buttonStyle(.plain)
                        .deleteDisabled(group.isBuiltIn)
                    }
                    .onDelete { offsets in
                        groupsPendingDeletion = offsets
                            .map { groups[$0] }
                            .filter { !$0.isBuiltIn }
                    }
                    .onMove(perform: moveGroups)
                } footer: {
                    Text("Collections keep related templates together.")
                }
            }
            .overlay {
                if groups.isEmpty && store.persistenceError == nil {
                    ContentUnavailableView {
                        Label("No collections", systemImage: "folder.badge.plus")
                    } description: {
                        Text("Collections keep related templates together.")
                    } actions: {
                        Button("New collection") { showingNewGroup = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !groups.isEmpty { EditButton() }
                    Button { showingNewGroup = true } label: { Label("New collection", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingNewGroup) { TemplateGroupEditorView(group: nil) }
            .sheet(item: $editingGroup) { TemplateGroupEditorView(group: $0) }
            .confirmationDialog(
                deleteConfirmationTitle,
                isPresented: Binding(
                    get: { !groupsPendingDeletion.isEmpty },
                    set: { if !$0 { groupsPendingDeletion = [] } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deletePendingGroup)
                Button("Cancel", role: .cancel) { groupsPendingDeletion = [] }
            } message: {
                Text(deleteConfirmationMessage)
            }
            .alert("Collections", isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(operationError ?? "")
            }
        }
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        let activeIDs = Set(reordered.map(\.id))
        let archivedIDs = store.templateGroups
            .filter { !activeIDs.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.id)
        guard store.reorderTemplateGroups(ids: reordered.map(\.id) + archivedIDs) else {
            operationError = "The collection order could not be saved."
            return
        }
    }

    private func deletePendingGroup() {
        let groupsToDelete = groupsPendingDeletion
        groupsPendingDeletion = []
        guard !groupsToDelete.isEmpty else { return }

        var allDeleted = true
        for group in groupsToDelete where !group.isBuiltIn {
            allDeleted = store.deleteTemplateGroup(id: group.id) && allDeleted
        }
        if !allDeleted {
            operationError = groupsToDelete.count == 1
                ? "The collection could not be deleted."
                : "One or more collections could not be deleted."
        }
    }

    private var deleteConfirmationTitle: String {
        groupsPendingDeletion.count == 1
            ? String(localized: "Delete collection?")
            : String(localized: "Delete collections?")
    }

    private var deleteConfirmationMessage: String {
        groupsPendingDeletion.count == 1
            ? String(localized: "Its templates are kept and moved to Ungrouped.")
            : String(localized: "Their templates are kept and moved to Ungrouped.")
    }
}

private struct CollectionRow: View {
    let group: TemplateGroup
    let templateCount: Int

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: group.iconID, tint: group.colorToken.templateColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(templateCount.formatted())
                        .monospacedDigit()
                    Text(templateCount == 1 ? String(localized: "Template") : String(localized: "Templates"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if group.isBuiltIn {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Locked")
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to edit this collection")
    }
}

/// Lays out compact template-variable buttons across as many rows as needed,
/// keeping every option visible without introducing a nested horizontal scroll.
private struct WrappingTokenLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maximumWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var requiredWidth: CGFloat = 0
        var requiredHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacing = rowWidth == 0 ? 0 : horizontalSpacing

            if rowWidth > 0, rowWidth + spacing + size.width > maximumWidth {
                requiredWidth = max(requiredWidth, rowWidth)
                requiredHeight += rowHeight + verticalSpacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += spacing + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        requiredWidth = max(requiredWidth, rowWidth)
        requiredHeight += rowHeight

        return CGSize(
            width: proposal.width ?? requiredWidth,
            height: requiredHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacing = x == bounds.minX ? 0 : horizontalSpacing

            if x > bounds.minX, x + spacing + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            } else {
                x += spacing
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct TemplateGroupEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TemplateGroup
    @State private var saveError: String?
    private let isEditing: Bool

    init(group: TemplateGroup?) {
        isEditing = group != nil
        var initialDraft = group ?? TemplateGroup(name: "", sortOrder: Int.max)
        if TemplateColorToken(rawValue: initialDraft.colorToken) == nil {
            initialDraft.colorToken = TemplateColorToken.indigo.rawValue
        }
        if !TemplateAppearance.groupIcons.contains(where: { $0.id == initialDraft.iconID }) {
            initialDraft.iconID = TemplateAppearance.groupIcons[0].id
        }
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        IconTile(systemImage: draft.iconID, tint: draft.colorToken.templateColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trimmedName.isEmpty ? String(localized: "New collection") : trimmedName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text("Collection")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Collection") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }

                Section("Appearance") {
                    NavigationLink {
                        CollectionIconPickerView(
                            selection: $draft.iconID,
                            colorToken: draft.colorToken
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text("Icon")
                            Spacer(minLength: 12)
                            HStack(spacing: 8) {
                                Image(systemName: draft.iconID)
                                Text(selectedIconTitle)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        CollectionColorPickerView(
                            selection: $draft.colorToken,
                            iconID: draft.iconID
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text("Color")
                            Spacer(minLength: 12)
                            Circle()
                                .fill(selectedColor.color)
                                .frame(width: 16, height: 16)
                                .overlay {
                                    Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                                }
                            Text(selectedColor.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit collection" : "New collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .alert("Could not save collection", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedIconTitle: String {
        TemplateAppearance.groupIcons.first(where: { $0.id == draft.iconID })?.title
            ?? String(localized: "Icon")
    }

    private var selectedColor: TemplateColorToken {
        TemplateColorToken(rawValue: draft.colorToken) ?? .indigo
    }

    private func save() {
        draft.name = trimmedName
        let didSave = isEditing
            ? store.updateTemplateGroup(draft)
            : store.addTemplateGroup(draft)
        guard didSave else {
            saveError = store.persistenceError ?? "The collection could not be saved."
            return
        }
        dismiss()
    }
}

private struct CollectionIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    let colorToken: String

    var body: some View {
        List(TemplateAppearance.groupIcons, id: \.id) { option in
            Button {
                selection = option.id
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemImage: option.id, tint: colorToken.templateColor)
                    Text(option.title)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection == option.id {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection == option.id ? .isSelected : [])
        }
        .navigationTitle("Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CollectionColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    let iconID: String

    var body: some View {
        List(TemplateColorToken.allCases) { option in
            Button {
                selection = option.rawValue
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemImage: iconID, tint: option.color)
                    Text(option.title)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection == option.rawValue {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection == option.rawValue ? .isSelected : [])
        }
        .navigationTitle("Color")
        .navigationBarTitleDisplayMode(.inline)
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
}
