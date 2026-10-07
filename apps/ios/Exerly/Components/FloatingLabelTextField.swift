import SwiftUI

struct FloatingLabelTextField: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFloating: Bool {
        isFocused || !text.isEmpty
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(label).font(.exCaption).foregroundStyle(.exTextSecondary).accessibilityHidden(true)
                    input
                }
            } else {
                ZStack(alignment: .leading) {
                    Text(label)
                        .font(isFloating ? .exCaption : .exBody)
                        .foregroundStyle(isFocused ? .exPrimaryText : .exTextMuted)
                        .offset(y: isFloating ? -22 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.3), value: isFloating)
                        .accessibilityHidden(true)
                    input.offset(y: 4)
                }
            }
        }
        .padding(.horizontal, ExSpacing.content)
        .padding(.vertical, ExSpacing.content)
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: ExRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: ExRadius.control)
                .stroke(
                    isFocused ? Color.exPrimary : Color.exBorder,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFocused)
    }

    private var input: some View {
        Group {
            if isSecure { SecureField("", text: $text) } else { TextField("", text: $text).keyboardType(keyboardType) }
        }
        .font(.exBody)
        .accessibilityLabel(label)
        .textInputAutocapitalization(keyboardType == .emailAddress || isSecure ? .never : .words)
        .autocorrectionDisabled(keyboardType == .emailAddress || isSecure)
        .foregroundStyle(.exTextPrimary)
        .focused($isFocused)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFocused {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
}
