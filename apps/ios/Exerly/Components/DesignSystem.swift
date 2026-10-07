import SwiftUI

enum ExSpacing {
    static let tight: CGFloat = 4
    static let small: CGFloat = 8
    static let item: CGFloat = 12
    static let content: CGFloat = 16
    static let page: CGFloat = 20
    static let section: CGFloat = 24
    static let major: CGFloat = 32
}

enum ExRadius {
    static let control: CGFloat = 12
    static let card: CGFloat = 24
}

/// One reading column, with room for both the tab bar and accessibility text.
struct ExScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ExSpacing.section) { content }
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, ExSpacing.page)
                .padding(.top, ExSpacing.content)
                .padding(.bottom, ExSpacing.major)
        }
        .background(Color.exBackground)
    }
}

struct ExCard<Content: View>: View {
    var accent = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.content) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ExSpacing.page)
            .background(accent ? Color.exPrimary.opacity(0.07) : Color.exSurface1)
            .clipShape(RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous)
                    .strokeBorder(accent ? Color.exPrimary.opacity(0.24) : Color.exBorder.opacity(0.5), lineWidth: 0.5)
            }
    }
}

struct ExEyebrow: View {
    let title: String
    var color: Color = .exTextSecondary

    init(_ title: String, color: Color = .exTextSecondary) { self.title = title; self.color = color }

    var body: some View {
        Text(title.uppercased()).font(.exSmall.weight(.semibold)).tracking(1.2)
            .foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}

struct ExSectionHeading: View {
    let title: String
    var detail: String?

    init(_ title: String, detail: String? = nil) { self.title = title; self.detail = detail }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.exH3).foregroundStyle(Color.exTextPrimary).accessibilityAddTraits(.isHeader)
            Spacer(minLength: ExSpacing.small)
            if let detail { Text(detail).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

struct ExActionStyle: ButtonStyle {
    var secondary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.exBodyMedium)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, ExSpacing.content).padding(.vertical, 14)
            .foregroundStyle(secondary ? Color.exPrimary : Color.white)
            .background(secondary ? Color.exPrimary.opacity(0.1) : Color.exPrimary)
            .clipShape(RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.75 : 1)
    }
}

struct ExEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let action: String
    var actionID = ""
    let perform: () -> Void

    var body: some View {
        ExCard {
            Image(systemName: icon).font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.exPrimary).frame(width: 56, height: 56)
                .background(Color.exPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                Text(title).font(.exH2).foregroundStyle(Color.exTextPrimary)
                Text(message).font(.exBody).foregroundStyle(Color.exTextSecondary)
            }.fixedSize(horizontal: false, vertical: true)
            Button(action, action: perform).buttonStyle(ExActionStyle()).accessibilityIdentifier(actionID)
        }
    }
}

struct ExNavigationLabel: View {
    let title: String
    let icon: String
    var detail: String?

    var body: some View {
        HStack(spacing: ExSpacing.item) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.exPrimary).frame(width: 42, height: 42)
                .background(Color.exPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: ExRadius.control))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                Text(title).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                if let detail { Text(detail).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                .foregroundStyle(Color.exTextMuted).accessibilityHidden(true)
        }.frame(minHeight: 48).contentShape(Rectangle())
    }
}

struct ExProgressBar: View {
    let value: Double
    let total: Double
    var color: Color = .exPrimary

    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(color.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: geometry.size.width * (total > 0 ? min(max(value / total, 0), 1) : 0))
                }
        }.frame(height: 5).accessibilityHidden(true)
    }
}

struct ExChoiceChips<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    var title: (Value) -> String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ExSpacing.small) { choices }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ExSpacing.small) { choices }
                ScrollView(.horizontal) { HStack(spacing: ExSpacing.small) { choices } }.scrollIndicators(.hidden)
            }
        }
    }

    private var choices: some View {
        ForEach(values, id: \.self) { value in
            Button { selection = value } label: {
                Text(title(value)).font(.exLabel).fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .foregroundStyle(selection == value ? Color.white : Color.exTextSecondary)
                    .background(selection == value ? Color.exPrimary : Color.exSurface2, in: Capsule())
            }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
        }
    }
}

struct ExQuantityControl: View {
    let title: String
    @Binding var text: String
    var step: Double = 1
    var presets: [Double] = []
    var unit = ""
    var identifier = ""
    var integer = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            Text(title).font(.exLabel).foregroundStyle(Color.exTextSecondary)
            HStack(spacing: ExSpacing.item) {
                adjustment("minus", amount: -step, label: "Decrease \(title)")
                ExNumericTextField(title: title, text: $text, integer: integer, centered: true, identifier: identifier).frame(minHeight: 52)
                adjustment("plus", amount: step, label: "Increase \(title)")
            }
            if !presets.isEmpty {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    ForEach(presets, id: \.self) { value in
                        Button("\(value.formatted(.number.precision(.fractionLength(0...2))))\(unit.isEmpty ? "" : " " + unit)") {
                            text = value.formatted(.number.grouping(.never).precision(.fractionLength(0...8)))
                        }.font(.exLabel).frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                            .buttonStyle(.plain).foregroundStyle(Color.exPrimary)
                    }
                }
            }
        }
    }

    private func adjustment(_ symbol: String, amount: Double, label: String) -> some View {
        Button {
            let formatter = NumberFormatter()
            formatter.locale = .current
            formatter.numberStyle = .decimal
            guard let number = formatter.number(from: text)?.doubleValue, number.isFinite else { return }
            text = max(0, number + amount).formatted(.number.grouping(.never).precision(.fractionLength(0...8)))
        } label: {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 44, height: 44)
                .background(Color.exSurface2, in: Circle())
        }.buttonStyle(.plain).foregroundStyle(Color.exPrimary).accessibilityLabel(label)
    }
}

struct ExSegmentedControl<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        layout {
            ForEach(values, id: \.self) { value in
                Button { selection = value } label: {
                    Text(title(value)).font(.exLabel).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 6)
                        .foregroundStyle(value == selection ? Color.exTextPrimary : Color.exTextSecondary)
                        .background(value == selection ? Color.exSurface1 : .clear,
                                    in: RoundedRectangle(cornerRadius: ExRadius.control - 3))
                }.buttonStyle(.plain).accessibilityAddTraits(value == selection ? .isSelected : [])
            }
        }.padding(4).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
    }
}

extension View {
    func exListStyle() -> some View {
        self.listStyle(.insetGrouped).listSectionSpacing(ExSpacing.section)
            .scrollContentBackground(.hidden).background(Color.exBackground)
            .environment(\.defaultMinListRowHeight, 52)
            .tint(Color.exPrimary)
    }
}
