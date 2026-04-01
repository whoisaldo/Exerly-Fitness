import SwiftUI

struct FloatingLabelTextField: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    private var isFloating: Bool {
        isFocused || !text.isEmpty
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(label)
                .font(isFloating ? .exCaption : .exBody)
                .foregroundStyle(isFocused ? .exPrimary : .exTextMuted)
                .offset(y: isFloating ? -22 : 0)
                .animation(.spring(response: 0.3), value: isFloating)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .font(.exBody)
            .foregroundStyle(.exTextPrimary)
            .focused($isFocused)
            .offset(y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color.exPrimary : Color.exBorder,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}
