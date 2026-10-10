import SwiftUI

/// The first screen: the mark and the pulse, what Exerly does in three
/// lines, and the two ways in.
struct WelcomeView: View {
    let onLogin: () -> Void
    let onSignup: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            AuthBackdrop()
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: typeSize.isAccessibilitySize ? ExSpacing.section : 56)
                        brand
                        Spacer(minLength: ExSpacing.major)
                        features
                        Spacer(minLength: ExSpacing.major)
                        actions
                    }
                    .frame(maxWidth: 480, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, ExSpacing.section)
                    .padding(.bottom, ExSpacing.content)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { shown = true }
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: ExSpacing.content) {
            ZStack(alignment: .leading) {
                if !typeSize.isAccessibilitySize {
                    AuthPulse().frame(height: 56).padding(.leading, 40).padding(.trailing, -ExSpacing.section)
                }
                ExerlyMarkTile(size: typeSize.isAccessibilitySize ? 64 : 84)
            }
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                Text("Exerly").font(.exDisplay).foregroundStyle(Color.exTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Food, training and your body, in one place.")
                    .font(.exH3.weight(.regular)).foregroundStyle(Color.exTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 16)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: ExSpacing.content) {
            feature("fork.knife", title: "Log food in seconds", detail: "Search, scan a barcode, or repeat yesterday's meal.")
            feature("dumbbell.fill", title: "Train with a plan", detail: "Sets fill in from your plan or your last session.")
            feature("chart.line.uptrend.xyaxis", title: "See what's working", detail: "Trend weight, expenditure and weekly check-ins.")
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 24)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.15), value: shown)
    }

    private func feature(_ icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: ExSpacing.item) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.exPrimaryText)
                    .frame(width: 40, height: 40)
                    .background(Color.exPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                Text(detail).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: ExSpacing.small) {
            Button("Get Started", action: onSignup).buttonStyle(ExActionStyle())
            Button("I already have an account", action: onLogin).buttonStyle(ExActionStyle(secondary: true))
        }
        .opacity(shown ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.3), value: shown)
    }
}
