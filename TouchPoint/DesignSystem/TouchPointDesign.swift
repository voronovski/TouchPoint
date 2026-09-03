import SwiftUI

enum TouchPointColor {
    static let coral = Color(red: 0.91, green: 0.33, blue: 0.28)
    static let rose = Color(red: 0.79, green: 0.27, blue: 0.48)
    static let amber = Color(red: 0.74, green: 0.48, blue: 0.06)
    static let forest = Color(red: 0.16, green: 0.48, blue: 0.31)
    static let teal = Color(red: 0.05, green: 0.49, blue: 0.52)
}

enum TouchPointMetric {
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let iconSize: CGFloat = 28
    static let buttonHeight: CGFloat = 50
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
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct TouchPointPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: TouchPointMetric.buttonHeight)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
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

extension Date {
    var touchPointDay: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var touchPointTime: String {
        formatted(date: .omitted, time: .shortened)
    }
}
