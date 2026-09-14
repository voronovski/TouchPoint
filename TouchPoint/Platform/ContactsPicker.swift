import Contacts
import ContactsUI
import SwiftUI

struct ContactsPicker: View {
    let onSelect: ([Person]) -> Void
    let onCancel: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var entries: [ContactImportEntry] = []
    @State private var selectedIDs: Set<String> = []
    @State private var authorization = CNContactStore.authorizationStatus(for: .contacts)
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showingAccessPicker = false
    @State private var reloadID = UUID()
    private let loader = PhoneBookLoader()

    private var filteredEntries: [ContactImportEntry] {
        entries.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                if authorization == .limited {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search includes only contacts you have shared with Touch Point.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Manage contact access") { showingAccessPicker = true }
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                content
            }
            .navigationTitle("Import from Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selectedIDs.count))", action: importSelection)
                        .disabled(selectedIDs.isEmpty || isLoading || loadFailed)
                        .accessibilityLabel(Text("Import selected contacts"))
                        .accessibilityValue(Text("\(selectedIDs.count) selected"))
                }
            }
        }
        .task(id: reloadID) { await loadContacts() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reloadID = UUID() }
        }
        .contactAccessPicker(isPresented: $showingAccessPicker) { _ in
            reloadID = UUID()
        }
    }

    // Keep search above the list, visible even after scrolling or showing the keyboard.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Name, phone, or email", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("contactsImportSearch")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading contacts…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if authorization == .denied || authorization == .restricted {
            ContentUnavailableView {
                Label("Contacts access is unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                if authorization == .restricted {
                    Text("Contact access is restricted on this device.")
                } else {
                    Text("Allow contact access in Settings to search your phone book and choose people to import.")
                }
            } actions: {
                if authorization == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
        } else if loadFailed {
            ContentUnavailableView {
                Label("Could not load contacts", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Please try loading your contacts again.")
            } actions: {
                Button("Try again") { reloadID = UUID() }
            }
        } else {
            let matches = filteredEntries
            List(matches) { entry in
                Button {
                    if !selectedIDs.insert(entry.id).inserted { selectedIDs.remove(entry.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIDs.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIDs.contains(entry.id) ? Color.accentColor : .secondary)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.person.name).foregroundStyle(.primary)
                            let detail = [entry.person.organization, entry.person.phone, entry.person.email]
                                .filter { !$0.isEmpty }.joined(separator: " · ")
                            if !detail.isEmpty {
                                Text(detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedIDs.contains(entry.id) ? .isSelected : [])
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if matches.isEmpty {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("No contacts available", systemImage: "person.crop.circle")
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadContacts() async {
        isLoading = true
        loadFailed = false
        do {
            if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
                _ = try await CNContactStore().requestAccess(for: .contacts)
            }
            try Task.checkCancellation()
            authorization = CNContactStore.authorizationStatus(for: .contacts)
            if authorization == .authorized || authorization == .limited {
                let loaded = try await loader.load()
                try Task.checkCancellation()
                entries = loaded
                selectedIDs.formIntersection(Set(loaded.map(\.id)))
            } else {
                entries = []
                selectedIDs = []
            }
            isLoading = false
        } catch is CancellationError {
            // A newer reload or dismissal owns the view now.
        } catch {
            guard !Task.isCancelled else { return }
            authorization = CNContactStore.authorizationStatus(for: .contacts)
            entries = []
            selectedIDs = []
            loadFailed = true
            isLoading = false
        }
    }

    private func importSelection() {
        onSelect(entries.filter { selectedIDs.contains($0.id) }.map(\.person))
    }
}
