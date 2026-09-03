import SwiftUI

struct TemplatesView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var selectedTemplate: GreetingTemplate?
    @State private var showingNewTemplate = false

    private var sortedTemplates: [GreetingTemplate] {
        store.templates.sorted {
            let leftRank = preferences.mode.occasionRank($0.occasion)
            let rightRank = preferences.mode.occasionRank($1.occasion)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            if $0.isFavorite != $1.isFavorite {
                return $0.isFavorite
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedTemplates) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(systemImage: template.occasion.icon, tint: template.occasion.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(template.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if template.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(TouchPointColor.amber)
                                    }
                                }
                                Text(template.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewTemplate = true
                    } label: {
                        Label("New template", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                NewTemplateView(defaultOccasion: preferences.mode.occasionPriority[0])
            }
            .sheet(item: $selectedTemplate) { template in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            IconTile(systemImage: template.occasion.icon, tint: template.occasion.tint)
                            Text(template.title)
                                .font(.title2.bold())
                            Text(template.occasion.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            SurfaceCard {
                                Text(template.message)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle("Template")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedTemplate = nil }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

private struct NewTemplateView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var occasion: Occasion
    @State private var message = ""

    init(defaultOccasion: Occasion) {
        _occasion = State(initialValue: defaultOccasion)
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Template name", text: $title)
                    Picker("Occasion", selection: $occasion) {
                        ForEach(Occasion.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                } header: {
                    Text("Message")
                } footer: {
                    Text("Use {{first_name}} to personalize the greeting.")
                }
            }
            .navigationTitle("New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addTemplate(
                            GreetingTemplate(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                occasion: occasion,
                                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                                isFavorite: false
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}
