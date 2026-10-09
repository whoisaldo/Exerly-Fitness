import SwiftUI
import UIKit

/// One editable value in the workout's set grid, such as set 2's weight.
struct TrainingCell: Hashable {
    enum Field: Hashable { case load, reps, rir, duration, distance }
    let setID: UUID
    let field: Field
}

/// A set value edited in place. Tapping it opens the training keypad; the
/// first key replaces the value, as in other gym loggers, and later keys add
/// to it. The value is committed when editing ends, through Next, Done or
/// another cell.
struct TrainingValueField: UIViewRepresentable {
    let cell: TrainingCell
    let text: String
    var placeholder = "–"
    /// Shown above the keypad, such as "Set 2 · Weight (lb)".
    let title: String
    let accessibilityLabel: String
    let identifier: String
    var decimal = true
    let stepLabel: String
    @Binding var focus: TrainingCell?
    /// The value one step down or up from the given text, or nil to keep it.
    let step: (String, Bool) -> String?
    let next: (() -> Void)?
    let commit: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.adjustsFontForContentSizeCategory = true
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 11
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let input = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 284), inputViewStyle: .keyboard)
        let host = UIHostingController(rootView: keypad(for: field, coordinator: context.coordinator))
        // UIKit already places this inside the keyboard area; SwiftUI's
        // keyboard safe area would push the keypad header out of view.
        host.safeAreaRegions = .container
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        input.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: input.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: input.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: input.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: input.bottomAnchor)
        ])
        context.coordinator.host = host
        field.inputView = input
        updateUIView(field, context: context)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if !field.isFirstResponder, field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                         attributes: [.foregroundColor: UIColor(Color.exTextMuted)])
        field.accessibilityLabel = accessibilityLabel
        field.accessibilityIdentifier = identifier
        field.keyboardType = decimal ? .decimalPad : .numberPad
        field.textColor = UIColor(Color.exTextPrimary)
        // The focused cell's border shows editing; a caret would suggest typing appends.
        field.tintColor = .clear
        let base = UIFont.preferredFont(forTextStyle: .body)
        let descriptor = (base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        field.font = UIFont(descriptor: descriptor, size: 0)
        context.coordinator.host?.rootView = keypad(for: field, coordinator: context.coordinator)
        if focus == cell, !field.isFirstResponder {
            DispatchQueue.main.async { if focus == cell, field.window != nil { field.becomeFirstResponder() } }
        } else if focus == nil, field.isFirstResponder {
            DispatchQueue.main.async { if focus == nil { field.resignFirstResponder() } }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 60, height: max(36, (uiView.font?.lineHeight ?? 22) + 14))
    }

    private func keypad(for field: UITextField, coordinator: Coordinator) -> TrainingKeypad {
        TrainingKeypad(title: title, decimal: decimal, stepLabel: stepLabel, hasNext: next != nil, colorScheme: colorScheme,
                       insert: { [weak field, weak coordinator] key in
                           guard let field, let coordinator else { return }
                           _ = coordinator.textField(field, shouldChangeCharactersIn: NSRange(location: (field.text ?? "").utf16.count, length: 0),
                                                     replacementString: key, applying: true)
                       },
                       delete: { [weak field, weak coordinator] in
                           guard let field, let coordinator else { return }
                           let text = field.text ?? ""
                           _ = coordinator.textField(field, shouldChangeCharactersIn: NSRange(location: max(0, text.utf16.count - 1), length: text.isEmpty ? 0 : 1),
                                                     replacementString: "", applying: true)
                       },
                       step: { [weak field, weak coordinator] up in
                           guard let field, let coordinator, let value = coordinator.parent.step(field.text ?? "", up) else { return }
                           field.text = value
                           coordinator.replaceOnInput = true
                       },
                       next: { [weak coordinator] in coordinator?.parent.next?() },
                       done: { [weak coordinator] in coordinator?.parent.focus = nil })
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TrainingValueField
        var host: UIHostingController<TrainingKeypad>?
        /// Set when editing begins and after a step, so the next key starts a new value.
        var replaceOnInput = false
        private var initial = ""

        init(_ parent: TrainingValueField) { self.parent = parent }

        func textFieldDidBeginEditing(_ field: UITextField) {
            initial = field.text ?? ""
            replaceOnInput = true
            if parent.focus != parent.cell { parent.focus = parent.cell }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            if parent.focus == parent.cell { parent.focus = nil }
            let text = field.text ?? ""
            if text != initial { parent.commit(text) }
        }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            textField(field, shouldChangeCharactersIn: range, replacementString: string, applying: false)
        }

        /// Hardware keys and pasted text arrive here and are allowed through;
        /// the training keypad applies its keys itself. Either way the first
        /// change after editing begins replaces the whole value.
        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String,
                       applying: Bool) -> Bool {
            let separator = Locale.current.decimalSeparator ?? "."
            let allowed = parent.decimal ? CharacterSet(charactersIn: "0123456789" + separator) : CharacterSet(charactersIn: "0123456789")
            guard string.unicodeScalars.allSatisfy(allowed.contains) else { return false }
            let replacing = replaceOnInput
            let result = replacing ? string : ((field.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            guard result.count <= 7, result.components(separatedBy: separator).count <= 2 else { return false }
            replaceOnInput = false
            if replacing || applying {
                field.text = result
                return false
            }
            return true
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            if let next = parent.next { next() } else { parent.focus = nil }
            return false
        }

    }
}

/// Digits, steppers that follow the gym's plates, and Next, for logging sets
/// without leaving the workout.
struct TrainingKeypad: View {
    let title: String
    let decimal: Bool
    let stepLabel: String
    let hasNext: Bool
    let colorScheme: ColorScheme
    let insert: (String) -> Void
    let delete: () -> Void
    let step: (Bool) -> Void
    let next: () -> Void
    let done: () -> Void

    private var separator: String { Locale.current.decimalSeparator ?? "." }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.exTextSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8).accessibilityHidden(true)
                Spacer()
                Button("Done", action: done).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.exPrimaryText).frame(minWidth: 60, minHeight: 44).contentShape(Rectangle())
                    .accessibilityIdentifier("exerly.keypadDone")
            }
            HStack(spacing: 6) {
                VStack(spacing: 6) {
                    row(["1", "2", "3"])
                    row(["4", "5", "6"])
                    row(["7", "8", "9"])
                    HStack(spacing: 6) {
                        if decimal { key(separator) { insert(separator) }.accessibilityLabel("Decimal separator") }
                        else { Color.clear.frame(maxWidth: .infinity, minHeight: 48).accessibilityHidden(true) }
                        key("0") { insert("0") }
                        Button(action: delete) {
                            Image(systemName: "delete.left").font(.system(size: 20))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.control))
                        }.buttonStyle(.plain).accessibilityLabel("Delete digit").accessibilityIdentifier("exerly.keypad.delete")
                    }
                }
                VStack(spacing: 6) {
                    stepper(up: false)
                    stepper(up: true)
                    Button(action: hasNext ? next : done) {
                        VStack(spacing: 2) {
                            Image(systemName: hasNext ? "arrow.turn.down.right" : "checkmark").font(.system(size: 18, weight: .semibold))
                            Text(hasNext ? "Next" : "Done").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.exActionFill, in: RoundedRectangle(cornerRadius: ExRadius.control))
                    }.buttonStyle(.plain)
                        .accessibilityLabel(hasNext ? "Next value" : "Done")
                        .accessibilityIdentifier("training.keypadNext")
                }.frame(width: 84)
            }.fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, ExSpacing.item).padding(.bottom, ExSpacing.item)
        .foregroundStyle(Color.exTextPrimary).background(Color.exSurface2)
        .environment(\.colorScheme, colorScheme)
    }

    private func row(_ keys: [String]) -> some View {
        HStack(spacing: 6) { ForEach(keys, id: \.self) { value in key(value) { insert(value) } } }
    }

    private func key(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.system(size: 24, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.control))
        }.buttonStyle(.plain).accessibilityIdentifier("exerly.keypad.\(title)")
    }

    private func stepper(up: Bool) -> some View {
        Button { step(up) } label: {
            VStack(spacing: 0) {
                Image(systemName: up ? "plus" : "minus").font(.system(size: 17, weight: .bold))
                Text(stepLabel).font(.system(size: 11, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.exPrimaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.exPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: ExRadius.control))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: title)
        .accessibilityLabel("\(up ? "Increase" : "Decrease") by \(stepLabel)")
        .accessibilityIdentifier(up ? "training.keypadPlus" : "training.keypadMinus")
    }
}

/// A compact row for the training home's secondary destinations.
struct TrainingToolLabel: View {
    let title: String
    let icon: String
    var detail: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: ExSpacing.item) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.exPrimaryText).frame(width: 28)
                .accessibilityHidden(true)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: ExSpacing.small))
            layout {
                Text(title).font(.exBody).foregroundStyle(Color.exTextPrimary)
                if !typeSize.isAccessibilitySize { Spacer(minLength: ExSpacing.small) }
                if let detail {
                    Text(detail).font(.exLabel).foregroundStyle(Color.exTextSecondary)
                        .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                .foregroundStyle(Color.exTextMuted).accessibilityHidden(true)
        }
        .frame(minHeight: 44).contentShape(Rectangle()).multilineTextAlignment(.leading)
        .padding(.horizontal, ExSpacing.content).padding(.vertical, 6)
    }
}
