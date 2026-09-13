import SwiftUI

struct OccasionsView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var editingNode: OccasionNode?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OccasionTreeRows(query: query, showsTemplate: true, onSelect: { editingNode = $0 })
                } footer: {
                    if !store.occasionNodes.isEmpty {
                        Text("Attach a template to an occasion to automatically plan a greeting when you add that occasion to a person.")
                    }
                }
            }
            .overlay {
                if store.occasionNodes.isEmpty {
                    ContentUnavailableView {
                        Label("No occasions", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Add an occasion or a group to get started.")
                    } actions: {
                        Button("New occasion", systemImage: "calendar.badge.plus") {
                            editingNode = OccasionNode(sortOrder: store.nextOccasionPosition(in: nil))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Occasions")
            .searchable(text: $query, prompt: "Search occasions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New occasion", systemImage: "calendar.badge.plus") {
                            editingNode = OccasionNode(sortOrder: store.nextOccasionPosition(in: nil))
                        }
                        Button("New group", systemImage: "folder.badge.plus") {
                            editingNode = OccasionNode(isGroup: true, sortOrder: store.nextOccasionPosition(in: nil))
                        }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add occasion or group")
                }
            }
            .sheet(item: $editingNode) { node in
                OccasionEditorView(node: node)
            }
        }
    }
}

/// The same expandable hierarchy is used for managing the library and attaching a date.
private struct OccasionTreeRows: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var expanded: Set<String> = ["group:personal"]
    var query: String
    var showsTemplate = false
    var selectionID: String?
    let onSelect: (OccasionNode) -> Void

    private struct Row: Identifiable {
        var node: OccasionNode
        var depth: Int
        var id: String { node.id }
    }

    private var rows: [Row] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var included = Set<String>()
        if !needle.isEmpty {
            for node in store.occasionNodes where store.occasionPath(node).localizedStandardContains(needle) {
                included.insert(node.id)
                var parentID = node.parentID
                while let id = parentID, included.insert(id).inserted {
                    parentID = store.occasionNodes.first { $0.id == id }?.parentID
                }
            }
        }
        var result: [Row] = []
        func appendChildren(of parentID: String?, depth: Int) {
            let children = store.occasionNodes.filter { $0.parentID == parentID }.sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            for node in children {
                if !needle.isEmpty && !included.contains(node.id) { continue }
                if !showsTemplate, let category = node.builtInCategoryID.flatMap(OccasionCategory.init(rawValue:)),
                   !preferences.isOccasionCategoryEnabled(category) { continue }
                result.append(Row(node: node, depth: depth))
                if node.isGroup && (expanded.contains(node.id) || !needle.isEmpty) {
                    appendChildren(of: node.id, depth: depth + 1)
                }
            }
        }
        appendChildren(of: nil, depth: 0)
        return result
    }

    var body: some View {
        ForEach(rows) { row in
            HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
                Button {
                    if row.node.isGroup {
                        if !expanded.insert(row.id).inserted { expanded.remove(row.id) }
                    } else { onSelect(row.node) }
                } label: {
                    HStack(spacing: 12) {
                        if row.node.isGroup {
                            FormIconTile(systemImage: row.node.icon)
                        } else {
                            IconTile(systemImage: row.node.icon, tint: row.node.occasion.tint)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.node.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if showsTemplate && !row.node.isGroup {
                                Text(store.attachedTemplate(for: row.node)?.title ?? String(localized: "No template attached"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if row.node.isGroup {
                            Image(systemName: expanded.contains(row.id) || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        } else if row.id == selectionID {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.accent)
                                .accessibilityHidden(true)
                        } else if showsTemplate {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(row.id == selectionID ? .isSelected : [])
                .accessibilityHint(row.node.isGroup ? String(localized: "Expand or collapse group") :
                                    (showsTemplate ? String(localized: "Edit occasion") : String(localized: "Choose occasion")))
                if showsTemplate && row.node.isGroup {
                    Button { onSelect(row.node) } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Edit") + Text(": ") + Text(row.node.title))
                }
            }
            .padding(.leading, CGFloat(min(row.depth, 6)) * 16)
            .onAppear {
                guard row.id == store.occasionNodes.first(where: { $0.parentID == nil })?.id,
                      let selected = store.occasionNodes.first(where: { $0.id == selectionID }) else { return }
                var parentID = selected.parentID
                while let id = parentID, expanded.insert(id).inserted {
                    parentID = store.occasionNodes.first { $0.id == id }?.parentID
                }
            }
        }
        if rows.isEmpty && !query.isEmpty { ContentUnavailableView.search(text: query) }
    }
}

struct OccasionLibraryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var selectionID: String?
    let onSelect: (OccasionNode) -> Void

    var body: some View {
        NavigationStack {
            List {
                OccasionTreeRows(query: query, selectionID: selectionID) { node in
                    onSelect(node)
                    dismiss()
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "Search occasions")
            .navigationTitle("Occasion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct OccasionEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OccasionNode
    @State private var title: String
    @State private var error: String?
    @State private var confirmingDelete = false
    @State private var choosingTemplate = false
    @State private var choosingParent = false
    @State private var child: OccasionNode?
    private let initialTitle: String

    init(node: OccasionNode) {
        _draft = State(initialValue: node)
        _title = State(initialValue: node.title)
        initialTitle = node.title
    }

    private var exists: Bool { store.occasionNodes.contains { $0.id == draft.id } }
    private var parentOptions: [OccasionNode] {
        let excluded = store.occasionDescendants(of: draft.id).union([draft.id])
        return store.occasionNodes.filter { $0.isGroup && !excluded.contains($0.id) }
            .sorted { store.occasionPath($0).localizedStandardCompare(store.occasionPath($1)) == .orderedAscending }
    }
    private var parentTitle: String {
        store.occasionNodes.first { $0.id == draft.parentID }.map { store.occasionPath($0) }
            ?? String(localized: "Top level")
    }
    private var attachedTemplate: GreetingTemplate? { store.templates.first { $0.id == draft.templateID } }
    private var maximumDay: Int { [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][draft.month - 1] }
    private var navigationTitle: LocalizedStringKey {
        if draft.isGroup { return exists ? "Occasion group" : "New group" }
        return exists ? "Edit occasion" : "New occasion"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TouchPointMetric.sectionSpacing) {
                    detailsSection
                    if !draft.isGroup {
                        dateSection
                        templateSection
                    } else if exists {
                        childrenSection
                    }
                    if let error {
                        SurfaceCard {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(TouchPointMetric.cardPadding)
                        }
                    }
                    if exists {
                        TouchPointDeleteButton(title: draft.isGroup ? "Delete group" : "Delete occasion") {
                            confirmingDelete = true
                        }
                    }
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.vertical, TouchPointMetric.scrollPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(exists ? "Save" : "Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: draft.parentID) { draft.sortOrder = store.nextOccasionPosition(in: draft.parentID) }
            .onChange(of: draft.month) { draft.day = min(draft.day, maximumDay) }
            .onChange(of: draft) { error = nil }
            .onChange(of: title) { error = nil }
            .sheet(isPresented: $choosingParent) {
                OccasionParentPicker(groups: parentOptions, selection: $draft.parentID)
            }
            .sheet(isPresented: $choosingTemplate) {
                OccasionTemplatePicker(selection: $draft.templateID)
            }
            .sheet(item: $child) { OccasionEditorView(node: $0) }
            .confirmationDialog("Delete this item?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if store.deleteOccasionNode(id: draft.id) { dismiss() }
                    else { error = store.persistenceError }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saved dates and greetings remain. Items inside a deleted group move to its parent group.")
            }
        }
    }

    private var detailsSection: some View {
        SurfaceSection(title: "Details") {
            FormFieldRow(title: "Name", systemImage: draft.isGroup ? "folder" : "calendar") {
                TextField("Name", text: $title,
                          prompt: Text("Name").foregroundStyle(Color(uiColor: .placeholderText)))
                    .textInputAutocapitalization(.sentences)
            }
            SurfaceRowDivider()
            Button { choosingParent = true } label: {
                FormValueRow(title: "Parent group", value: parentTitle,
                             systemImage: "folder", showsDisclosure: true)
            }
            .buttonStyle(.plain)
            SurfaceRowDivider()
            FormFieldRow(title: "Position", systemImage: "arrow.up.arrow.down") {
                Stepper(value: $draft.sortOrder, in: 0...10_000) {
                    Text((draft.sortOrder + 1).formatted())
                        .monospacedDigit()
                }
                .accessibilityLabel("Position")
                .accessibilityValue((draft.sortOrder + 1).formatted())
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: TouchPointMetric.sectionHeadingSpacing) {
            SurfaceSection(title: "Annual date") {
                Menu {
                    Picker("Date", selection: $draft.dateRule) {
                        Text(OccasionDateRule.personDate.title).tag(OccasionDateRule.personDate)
                        Text(OccasionDateRule.fixedDate.title).tag(OccasionDateRule.fixedDate)
                        if let builtIn = draft.builtInOccasion, !Occasion.contactSpecificCases.contains(builtIn) {
                            Text(OccasionDateRule.calendar.title).tag(OccasionDateRule.calendar)
                        }
                    }
                } label: {
                    FormValueRow(title: "Date", value: draft.dateRule.title,
                                 systemImage: "calendar", showsDisclosure: true)
                }
                .buttonStyle(.plain)
                if draft.dateRule == .fixedDate {
                    SurfaceRowDivider()
                    Menu {
                        Picker("Month", selection: $draft.month) {
                            ForEach(1...12, id: \.self) { Text(Calendar.current.monthSymbols[$0 - 1]).tag($0) }
                        }
                    } label: {
                        FormValueRow(title: "Month", value: Calendar.current.monthSymbols[draft.month - 1],
                                     systemImage: "calendar", showsDisclosure: true)
                    }
                    .buttonStyle(.plain)
                    SurfaceRowDivider()
                    Menu {
                        Picker("Day", selection: $draft.day) {
                            ForEach(1...maximumDay, id: \.self) { Text($0.formatted()).tag($0) }
                        }
                    } label: {
                        FormValueRow(title: "Day", value: draft.day.formatted(),
                                     systemImage: "number", showsDisclosure: true)
                            .monospacedDigit()
                    }
                    .buttonStyle(.plain)
                }
            }
            footer("Date and template changes apply the next time this occasion is added to a person. Existing greetings keep their saved content.")
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: TouchPointMetric.sectionHeadingSpacing) {
            SurfaceSection(title: "Automatic greeting") {
                Button { choosingTemplate = true } label: {
                    FormValueRow(title: "Template", value: attachedTemplate?.title ?? String(localized: "None"),
                                 systemImage: "text.bubble", showsDisclosure: true)
                }
                .buttonStyle(.plain)
                if let template = attachedTemplate {
                    SurfaceRowDivider()
                    Text(template.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(TouchPointMetric.screenPadding)
                    if template.isArchived {
                        Label("This template is archived. Choose an active template to enable automatic planning.",
                              systemImage: "archivebox")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, TouchPointMetric.cardPadding)
                            .padding(.bottom, TouchPointMetric.cardPadding)
                    }
                    SurfaceRowDivider()
                    Button(role: .destructive) { draft.templateID = nil } label: {
                        Label("Detach template", systemImage: "link")
                    }
                    .buttonStyle(TouchPointTertiaryButtonStyle(tint: .red))
                    .frame(minHeight: 44)
                    .padding(TouchPointMetric.cardPadding)
                }
            }
            footer("When you save a person with this occasion, its attached template creates an annual greeting at 9:00 AM in their time zone. Without a template, only the important date is saved.")
        }
    }

    private var childrenSection: some View {
        SurfaceSection(title: "Occasions") {
            Button("New occasion", systemImage: "calendar.badge.plus") {
                child = OccasionNode(parentID: draft.id, sortOrder: store.nextOccasionPosition(in: draft.id))
            }
            .buttonStyle(TouchPointTertiaryButtonStyle())
            .frame(minHeight: 44)
            .padding(TouchPointMetric.cardPadding)
            SurfaceRowDivider()
            Button("New subgroup", systemImage: "folder.badge.plus") {
                child = OccasionNode(parentID: draft.id, isGroup: true, sortOrder: store.nextOccasionPosition(in: draft.id))
            }
            .buttonStyle(TouchPointTertiaryButtonStyle())
            .frame(minHeight: 44)
            .padding(TouchPointMetric.cardPadding)
        }
    }

    private func footer(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, TouchPointMetric.screenPadding)
    }

    private func save() {
        var savedDraft = draft
        if title != initialTitle { savedDraft.name = title }
        if store.saveOccasionNode(savedDraft) { dismiss() }
        else { error = store.persistenceError }
    }
}

private struct OccasionParentPicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let groups: [OccasionNode]
    @Binding var selection: String?
    @State private var query = ""

    private var visibleGroups: [OccasionNode] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return groups.filter { needle.isEmpty || store.occasionPath($0).localizedStandardContains(needle) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { selection = nil; dismiss() } label: {
                        OccasionSelectionRow(title: String(localized: "Top level"), systemImage: "tray",
                                             isSelected: selection == nil)
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    ForEach(visibleGroups) { group in
                        Button { selection = group.id; dismiss() } label: {
                            OccasionSelectionRow(title: group.title, subtitle: store.occasionPath(group),
                                                 systemImage: "folder", isSelected: selection == group.id)
                        }
                        .buttonStyle(.plain)
                    }
                    if visibleGroups.isEmpty && !query.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "Search groups")
            .navigationTitle("Parent group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

private struct OccasionTemplatePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: UUID?
    @State private var query = ""
    private var templates: [GreetingTemplate] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.templates.filter { !$0.isArchived && (needle.isEmpty || $0.title.localizedStandardContains(needle) || $0.body.localizedStandardContains(needle)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { selection = nil; dismiss() } label: {
                        OccasionSelectionRow(title: String(localized: "None"), systemImage: "nosign",
                                             isSelected: selection == nil)
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    ForEach(templates) { template in
                        Button { selection = template.id; dismiss() } label: {
                            OccasionSelectionRow(title: template.title, subtitle: template.body,
                                                 systemImage: template.icon, tint: template.colorToken.templateColor,
                                                 isSelected: selection == template.id)
                        }
                        .buttonStyle(.plain)
                    }
                    if templates.isEmpty {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView("No templates", systemImage: "text.bubble",
                                                   description: Text("Create a template in the Templates tab to attach it to an occasion."))
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "Search templates")
            .navigationTitle("Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

private struct OccasionSelectionRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var tint: Color?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: TouchPointMetric.rowContentAlignment, spacing: 12) {
            if let tint {
                IconTile(systemImage: systemImage, tint: tint)
                    .accessibilityHidden(true)
            } else {
                FormIconTile(systemImage: systemImage)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty, subtitle != title {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
