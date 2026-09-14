import SwiftUI
import UIKit

/// First-run walkthrough explaining the People -> Occasions -> Templates -> Plan
/// pipeline before the person lands on an empty Today tab with no context for it.
struct OnboardingView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let steps = OnboardingStep.all

    init() {
        // Keep the native page control readable on both grouped backgrounds.
        // The slightly lighter dark-mode value preserves a similar contrast
        // without changing the onboarding layout or interaction.
        UIPageControl.appearance().pageIndicatorTintColor = UIColor { traits in
            let gray: CGFloat = traits.userInterfaceStyle == .dark ? 0.54 : 0.48
            return UIColor(white: gray, alpha: 1)
        }
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor { traits in
            let gray: CGFloat = traits.userInterfaceStyle == .dark ? 0.72 : 0.32
            return UIColor(white: gray, alpha: 1)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        OnboardingPage(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page < steps.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    PrimaryButtonLabel(
                        title: page < steps.count - 1 ? String(localized: "Continue") : String(localized: "Get started"),
                        systemImage: page < steps.count - 1 ? "arrow.right" : "checkmark"
                    )
                }
                .buttonStyle(TouchPointPrimaryButtonStyle())
                .padding(.horizontal, TouchPointMetric.screenPadding)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { finish() }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func finish() {
        preferences.hasCompletedOnboarding = true
        dismiss()
    }
}

private struct OnboardingStep {
    let icon: String
    let tint: Color
    let title: String
    let message: String

    static let all: [OnboardingStep] = [
        OnboardingStep(
            icon: "person.2.fill",
            tint: .accentColor,
            title: String(localized: "Add the people you care about"),
            message: String(localized: "Start in People. Save a phone number, email, or just a name — Touch Point can remind you even without contact info.")
        ),
        OnboardingStep(
            icon: "calendar.badge.clock",
            tint: TouchPointColor.rose,
            title: String(localized: "Choose the occasions that matter"),
            message: String(localized: "Occasions holds birthdays, holidays, and your own custom moments. Attach a template to one to plan its greetings automatically.")
        ),
        OnboardingStep(
            icon: "rectangle.stack.fill",
            tint: TouchPointColor.teal,
            title: String(localized: "Fresh words for every occasion"),
            message: String(localized: "Add message variations to your templates. Touch Point alternates between them when planning greetings, helping you avoid the same words every time.")
        ),
        OnboardingStep(
            icon: "wand.and.sparkles",
            tint: TouchPointColor.amber,
            title: String(localized: "Plan the whole year in one pass"),
            message: String(localized: "Use \"Plan greetings\" on the Today tab to schedule everyone at once, or add a single greeting anytime from Calendar.")
        )
    ]
}

private struct OnboardingPage: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            Image(systemName: step.icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(step.tint)
                .frame(width: 92, height: 92)
                .background(step.tint.opacity(0.14))
                .clipShape(Circle())

            VStack(spacing: 10) {
                Text(step.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(step.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, TouchPointMetric.screenPadding)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingView()
        .environment(AppPreferences())
}
