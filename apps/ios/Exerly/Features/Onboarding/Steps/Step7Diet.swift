import SwiftUI

struct Step7Diet: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Dietary Preferences")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Help us tailor your nutrition plan")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                dietStyleSection
                allergiesSection
                mealsSection

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private var dietStyleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diet Style")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(DietaryStyle.allCases) { style in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            state.dietaryStyle = style
                        }
                    } label: {
                        Text(style.label)
                            .font(.exCaption)
                            .foregroundStyle(state.dietaryStyle == style ? .white : .exTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(state.dietaryStyle == style ? Color.exPrimary : Color.exGlassBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(state.dietaryStyle == style ? Color.clear : Color.exGlassBorder, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allergies (optional)")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
            FlowLayout(spacing: 8) {
                ForEach(Allergy.allCases) { allergy in
                    let selected = state.allergies.contains(allergy)
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            if selected { state.allergies.remove(allergy) }
                            else { state.allergies.insert(allergy) }
                        }
                    } label: {
                        Text(allergy.label)
                            .font(.exCaption)
                            .foregroundStyle(selected ? .white : .exTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? Color.exAccent : Color.exGlassBg)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var mealsSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Meals per day")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 12) {
                    ForEach(2...6, id: \.self) { n in
                        Button {
                            withAnimation(.spring(response: 0.3)) { state.mealsPerDay = n }
                        } label: {
                            Text("\(n)")
                                .font(.exBodyMedium)
                                .foregroundStyle(state.mealsPerDay == n ? .white : .exTextSecondary)
                                .frame(width: 44, height: 44)
                                .background(state.mealsPerDay == n ? Color.exPrimary : Color.exSurface2)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
