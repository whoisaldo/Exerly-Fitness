import SwiftUI
import UIKit

/// Uses the text field's selection, paste and hardware-keyboard behavior.
/// The keypad only inserts characters; the draft validates their meaning.
struct ExNumericTextField: UIViewRepresentable {
    let title: String
    @Binding var text: String
    var placeholder = ""
    var integer = false
    var centered = false
    var identifier = ""
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.adjustsFontForContentSizeCategory = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        let input = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 284), inputViewStyle: .keyboard)
        let host = UIHostingController(rootView: keypad(for: field, coordinator: context.coordinator))
        // UIKit already places this content inside the keyboard. Applying
        // SwiftUI's keyboard safe area again can hide the keypad header.
        host.safeAreaRegions = .container
        context.coordinator.host = host
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        input.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: input.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: input.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: input.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: input.bottomAnchor)
        ])
        field.inputView = input
        updateUIView(field, context: context)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(string: placeholder.isEmpty ? title : placeholder,
                                                         attributes: [.foregroundColor: UIColor(Color.exTextSecondary)])
        field.accessibilityLabel = title
        field.accessibilityIdentifier = identifier
        field.textAlignment = centered ? .center : .left
        field.keyboardType = integer ? .numberPad : .decimalPad
        field.textColor = UIColor(Color.exTextPrimary)
        field.tintColor = UIColor(Color.exPrimary)
        let base = UIFont.preferredFont(forTextStyle: centered ? .largeTitle : .title2)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        field.font = UIFont(descriptor: descriptor, size: 0)
        context.coordinator.host?.rootView = keypad(for: field, coordinator: context.coordinator)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 100, height: max(48, (uiView.font?.lineHeight ?? 34) + 8))
    }

    private func keypad(for field: UITextField, coordinator: Coordinator) -> AnyView {
        AnyView(ExNumericKeypad(title: title, integer: integer, insert: { [weak field, weak coordinator] key in
            guard let field else { return }
            field.insertText(key)
            coordinator?.changed(field)
        }, delete: { [weak field, weak coordinator] in
            guard let field else { return }
            field.deleteBackward()
            coordinator?.changed(field)
        }, done: { [weak field] in field?.resignFirstResponder() })
            .environment(\.colorScheme, colorScheme))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ExNumericTextField
        var host: UIHostingController<AnyView>?

        init(_ parent: ExNumericTextField) { self.parent = parent }

        @objc func changed(_ field: UITextField) { parent.text = field.text ?? "" }
    }
}

struct ExNumericKeypad: View {
    let title: String
    let integer: Bool
    let insert: (String) -> Void
    let delete: () -> Void
    let done: () -> Void

    private var decimal: String { Locale.current.decimalSeparator ?? "." }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.exTextSecondary)
                    .lineLimit(1).accessibilityHidden(true)
                Spacer()
                Button("Done", action: done).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.exPrimaryText).frame(minWidth: 60, minHeight: 44).contentShape(Rectangle())
                    .accessibilityIdentifier("exerly.keypadDone")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(1...9, id: \.self) { value in key(String(value)) { insert(String(value)) } }
                if integer { Color.clear.frame(height: 48).accessibilityHidden(true) } else { key(decimal) { insert(decimal) }.accessibilityLabel("Decimal separator") }
                key("0") { insert("0") }
                Button(action: delete) {
                    Image(systemName: "delete.left").font(.system(size: 22))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.control))
                }.buttonStyle(.plain).accessibilityLabel("Delete digit").accessibilityIdentifier("exerly.keypad.delete")
            }
        }.padding(.horizontal, ExSpacing.content).padding(.bottom, ExSpacing.item)
            .foregroundStyle(Color.exTextPrimary).background(Color.exSurface2)
    }

    private func key(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.system(size: 24, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.control))
        }.buttonStyle(.plain).accessibilityIdentifier("exerly.keypad.\(title)")
    }
}
