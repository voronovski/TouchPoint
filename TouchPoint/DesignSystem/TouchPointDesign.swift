import SwiftUI

enum TouchPointColor {
    static let indigo = Color(red: 88.0 / 255.0, green: 86.0 / 255.0, blue: 214.0 / 255.0)
    static let blue = Color(red: 0.16, green: 0.45, blue: 0.82)
    static let coral = Color(red: 0.91, green: 0.33, blue: 0.28)
    static let rose = Color(red: 0.79, green: 0.27, blue: 0.48)
    static let amber = Color(red: 0.74, green: 0.48, blue: 0.06)
    static let forest = Color(red: 0.16, green: 0.48, blue: 0.31)
    static let teal = Color(red: 0.05, green: 0.49, blue: 0.52)
}

/// Stable appearance identifiers shared by template and collection persistence.
/// Keeping the palette beside its rendering prevents a saved token from silently
/// falling back to the app accent because a picker and a color switch drift apart.
enum TemplateColorToken: String, CaseIterable, Identifiable {
    case indigo
    case blue
    case coral
    case rose
    case amber
    case forest
    case teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indigo: String(localized: "Indigo")
        case .blue: String(localized: "Blue")
        case .coral: String(localized: "Coral")
        case .rose: String(localized: "Rose")
        case .amber: String(localized: "Amber")
        case .forest: String(localized: "Forest")
        case .teal: String(localized: "Teal")
        }
    }

    var color: Color {
        switch self {
        case .indigo: TouchPointColor.indigo
        case .blue: TouchPointColor.blue
        case .coral: TouchPointColor.coral
        case .rose: TouchPointColor.rose
        case .amber: TouchPointColor.amber
        case .forest: TouchPointColor.forest
        case .teal: TouchPointColor.teal
        }
    }

    static func color(for rawValue: String) -> Color {
        Self(rawValue: rawValue)?.color ?? TouchPointColor.indigo
    }
}

extension String {
    var templateColor: Color { TemplateColorToken.color(for: self) }
}

enum TouchPointMetric {
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let scrollPadding: CGFloat = 18
    static let sectionHeadingSpacing: CGFloat = 10
    static let cardPadding: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let iconSize: CGFloat = 28
    static let buttonHeight: CGFloat = 50

    /// Leading and trailing icons in rows with stacked text are centered on
    /// the row's content. Reserve top alignment for a multiline text input.
    static let rowContentAlignment: VerticalAlignment = .center
    static let multilineTextFieldAlignment: VerticalAlignment = .top
}

/// Desk-style section for detail and editor screens. Collection screens keep
/// their native List; these cards group related values and draft controls.
struct SurfaceSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TouchPointMetric.sectionHeadingSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .accessibilityAddTraits(.isHeader)
            SurfaceCard {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SurfaceRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, TouchPointMetric.cardPadding * 2 + TouchPointMetric.iconSize)
    }
}

/// Neutral icon surfaces are for fields and metadata; occasion identity keeps
/// the semantic color treatment supplied by IconTile.
struct FormIconTile: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: TouchPointMetric.iconSize, height: TouchPointMetric.iconSize)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct FormFieldRow<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var alignment: VerticalAlignment = TouchPointMetric.rowContentAlignment
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: 12) {
            FormIconTile(systemImage: systemImage)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                content
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(TouchPointMetric.cardPadding)
    }
}

struct FormValueRow: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    var showsDisclosure = false

    var body: some View {
        HStack(spacing: 0) {
            FormFieldRow(title: title, systemImage: systemImage) {
                Text(value)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, TouchPointMetric.cardPadding)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
    }
}

struct IconTile: View {
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: TouchPointMetric.iconSize, height: TouchPointMetric.iconSize)
            .background(tint.opacity(0.12))
            .clipShape(.rect(cornerRadius: 7, style: .continuous))
    }
}

struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 40

    private var tint: Color {
        switch person.relationship {
        case .client: .accentColor
        case .family: TouchPointColor.rose
        case .friend: TouchPointColor.teal
        case .colleague: TouchPointColor.amber
        }
    }

    var body: some View {
        Text(person.initials)
            .font(size > 42 ? .subheadline.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

struct SectionHeading: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct StatusPill: View {
    let status: GreetingStatus

    private var tint: Color {
        switch status {
        case .planned: .accentColor
        case .ready: TouchPointColor.amber
        case .completed: TouchPointColor.forest
        case .skipped: .secondary
        }
    }

    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct TouchPointPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: TouchPointMetric.buttonHeight)
            .background(tint.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Shared trash symbol scale for deletion actions throughout the app.
struct TouchPointTrashIcon: View {
    var body: some View {
        Image(systemName: "trash")
            .imageScale(.large)
    }
}

/// Final entity deletion action, shared by person and occasion editors.
/// Keep confirmation and persistence in the caller; place outside surface cards.
struct TouchPointDeleteButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label {
                Text(title)
            } icon: {
                TouchPointTrashIcon()
                    .font(.caption)
            }
        }
        .buttonStyle(TouchPointPrimaryButtonStyle(tint: .red))
    }
}

/// A full-width tertiary action for `List`, `Form`, and grouped card rows.
/// The surrounding container owns its insets and separator; this style supplies
/// Touch Point's neutral icon tile, typography, tint, and pressed treatment.
struct TouchPointTertiaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(TouchPointTertiaryLabelStyle(tint: resolvedTint))
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(configuration.isPressed ? 0.55 : (isEnabled ? 1 : 0.6))
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var resolvedTint: Color {
        isEnabled ? tint : .secondary
    }
}

private struct TouchPointTertiaryLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .tint(tint)
                .frame(width: TouchPointMetric.iconSize, height: TouchPointMetric.iconSize)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 7, style: .continuous))

            configuration.title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Spacer(minLength: 0)
        }
    }
}

struct PrimaryButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
    }
}

enum OccasionPickerMode: Equatable {
    case single
    case multiple
}

/// Shared occasion selector used anywhere the app asks the user to choose a
/// moment. Keeping it in the design system prevents long, differently ordered
/// occasion menus from drifting apart as the calendar grows.
struct OccasionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var preferences
    @State private var query = ""
    @State private var selected: Set<Occasion>
    @State private var expandedCategories: Set<OccasionCategory>

    private let initialSelection: [Occasion]
    private let options: [Occasion]
    private let mode: OccasionPickerMode
    private let allowsEmptySelection: Bool
    private let title: String
    private let onSave: ([Occasion]) -> Void

    init(
        selection: [Occasion],
        options: [Occasion] = Occasion.allCases,
        mode: OccasionPickerMode,
        allowsEmptySelection: Bool = false,
        title: String? = nil,
        onSave: @escaping ([Occasion]) -> Void
    ) {
        let normalizedSelection = options.filter { selection.contains($0) }
        let selectedCategories = Set(normalizedSelection.map(\.category))
        let firstCategory = options.first.map(\.category)

        initialSelection = normalizedSelection
        self.options = options
        self.mode = mode
        self.allowsEmptySelection = allowsEmptySelection
        self.title = title ?? (mode == .single ? String(localized: "Occasion") : String(localized: "Occasions"))
        self.onSave = onSave
        _selected = State(initialValue: Set(normalizedSelection))
        _expandedCategories = State(initialValue: selectedCategories.union(firstCategory.map { [$0] } ?? []))
    }

    var body: some View {
        NavigationStack {
            List {
                if mode == .single, allowsEmptySelection {
                    Button {
                        commitSingleSelection(nil)
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: "line.3.horizontal.decrease.circle", tint: .secondary)
                            Text("Any occasion")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected.isEmpty {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected.isEmpty ? .isSelected : [])
                }

                ForEach(visibleCategories) { category in
                    DisclosureGroup(isExpanded: expansionBinding(for: category)) {
                        ForEach(visibleOccasions(in: category)) { occasion in
                            occasionRow(occasion)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: category.icon)
                                .foregroundStyle(.accent)
                                .frame(width: 22)
                            Text(category.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(visibleOccasions(in: category).count.formatted())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if visibleCategories.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search occasions")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if mode == .multiple {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onSave(orderedSelection)
                            dismiss()
                        }
                        .disabled(selected.isEmpty && !allowsEmptySelection)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Text(selectedCountTitle)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(selected.isEmpty && !allowsEmptySelection ? Color.red : Color.secondary)
                    }
                }
            }
            .onChange(of: query) {
                guard !normalized(query).isEmpty else { return }
                expandedCategories.formUnion(visibleCategories)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func occasionRow(_ occasion: Occasion) -> some View {
        Button {
            if mode == .single {
                commitSingleSelection(occasion)
            } else {
                toggle(occasion)
            }
        } label: {
            HStack(spacing: 12) {
                IconTile(systemImage: occasion.icon, tint: occasion.tint)
                Text(occasion.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: selectionIcon(for: occasion))
                    .font(.title3)
                    .foregroundStyle(selected.contains(occasion) ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected.contains(occasion) ? .isSelected : [])
    }

    private var visibleCategories: [OccasionCategory] {
        OccasionCategory.allCases.filter { !visibleOccasions(in: $0).isEmpty }
    }

    private func visibleOccasions(in category: OccasionCategory) -> [Occasion] {
        let categoryOptions = options.filter {
            $0.category == category
                && (preferences.isOccasionCategoryEnabled(category) || selected.contains($0))
        }
        let needle = normalized(query)
        guard !needle.isEmpty else { return categoryOptions }
        return categoryOptions.filter { occasion in
            normalized("\(occasion.title) \(occasion.rawValue) \(occasion.searchTerms) \(category.title) \(category.searchTerms)").contains(needle)
        }
    }

    private var orderedSelection: [Occasion] {
        let preserved = initialSelection.filter { selected.contains($0) }
        let appended = options.filter { selected.contains($0) && !preserved.contains($0) }
        return preserved + appended
    }

    private var selectedCountTitle: String {
        if selected.isEmpty && !allowsEmptySelection { return String(localized: "Select at least one occasion") }
        return String(localized: "\(selected.count) selected")
    }

    private func expansionBinding(for category: OccasionCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }

    private func selectionIcon(for occasion: Occasion) -> String {
        if mode == .single {
            return selected.contains(occasion) ? "checkmark.circle.fill" : "circle"
        }
        return selected.contains(occasion) ? "checkmark.circle.fill" : "circle"
    }

    private func commitSingleSelection(_ occasion: Occasion?) {
        selected = occasion.map { [$0] } ?? []
        onSave(occasion.map { [$0] } ?? [])
        dismiss()
    }

    private func toggle(_ occasion: Occasion) {
        if selected.contains(occasion) {
            selected.remove(occasion)
        } else {
            selected.insert(occasion)
        }
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension OccasionCategory {
    var icon: String {
        switch self {
        case .personal: "person.crop.circle"
        case .usHolidays: "flag"
        case .observances: "calendar.badge.clock"
        case .latinAmerican: "globe.americas"
        case .frenchHolidays, .germanHolidays, .italianHolidays, .portugueseHolidays,
             .russianHolidays, .ukrainianHolidays:
            "globe.europe.africa"
        case .japaneseHolidays, .koreanHolidays, .chineseHolidays:
            "globe.asia.australia"
        }
    }

    var searchTerms: String {
        switch self {
        case .personal: "personal moments anniversaries birthday"
        case .usHolidays: "us usa united states federal holidays"
        case .observances: "observances community dates"
        case .latinAmerican: "latin latino latina hispanic latin american dates"
        case .frenchHolidays: "france french français holidays"
        case .germanHolidays: "germany german deutsch holidays"
        case .italianHolidays: "italy italian italiano holidays"
        case .portugueseHolidays: "portugal portuguese português holidays"
        case .russianHolidays: "russia russian русский holidays"
        case .ukrainianHolidays: "ukraine ukrainian українська holidays"
        case .japaneseHolidays: "japan japanese 日本語 holidays"
        case .koreanHolidays: "korea korean 한국어 holidays"
        case .chineseHolidays: "china chinese 中文 holidays"
        }
    }
}

extension Date {
    var touchPointDay: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var touchPointTime: String {
        formatted(date: .omitted, time: .shortened)
    }

    func touchPointDay(in timeZoneIdentifier: String) -> String {
        var style = Date.FormatStyle.dateTime
            .weekday(.abbreviated)
            .month(.abbreviated)
            .day()
        style.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return formatted(style)
    }

    func touchPointTime(in timeZoneIdentifier: String) -> String {
        var style = Date.FormatStyle.dateTime
            .hour()
            .minute()
        style.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return formatted(style)
    }
}
