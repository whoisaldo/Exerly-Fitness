import SwiftUI

struct SelectionCard: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .exPrimary : .exTextSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            isSelected
                                ? Color.exPrimary.opacity(0.15)
                                : Color.exSurface2
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.exCaption)
                            .foregroundStyle(.exTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .exPrimary : .exTextMuted)
                    .font(.system(size: 22))
            }
            .padding(14)
            .background(isSelected ? Color.exPrimary.opacity(0.08) : Color.exGlassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.exPrimary.opacity(0.4) : Color.exGlassBorder,
                        lineWidth: 1
                    )
            )
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct MultiSelectGrid<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selected: Set<Item>
    let label: (Item) -> String
    let icon: ((Item) -> String)?
    var columns: Int = 2

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
            spacing: 10
        ) {
            ForEach(items) { item in
                SelectionCard(
                    title: label(item),
                    icon: icon?(item),
                    isSelected: selected.contains(item)
                ) {
                    if selected.contains(item) {
                        selected.remove(item)
                    } else {
                        selected.insert(item)
                    }
                }
            }
        }
    }
}
