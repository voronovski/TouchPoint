import SwiftUI

struct OnboardingView: View {
    @Environment(AppPreferences.self) private var preferences
    @State private var selection: Focus = .all

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    brandHeader

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose a starting focus")
                            .font(.title2.bold())
                        Text("Pick what you want to see first, or keep All. This is a focus—not an identity—and you can change it later without losing any people or plans.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(Focus.allCases) { focus in
                            focusButton(focus)
                        }
                    }
                }
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }

            Button {
                preferences.completeOnboarding(with: selection)
            } label: {
                PrimaryButtonLabel(title: "Continue", systemImage: "arrow.right")
            }
            .buttonStyle(TouchPointPrimaryButtonStyle())
            .padding(TouchPointMetric.screenPadding)
            .background(.bar)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.accent)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Touch Point")
                    .font(.title.bold())
                Text("Plan once. Never forget again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func focusButton(_ focus: Focus) -> some View {
        let isSelected = selection == focus

        return Button {
            selection = focus
        } label: {
            HStack(alignment: .top, spacing: 14) {
                IconTile(systemImage: focus.icon, tint: isSelected ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(focus.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(focus.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(focus.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: TouchPointMetric.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TouchPointMetric.cardRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    OnboardingView()
        .environment(AppPreferences(defaults: UserDefaults(suiteName: "OnboardingPreview")!))
}
