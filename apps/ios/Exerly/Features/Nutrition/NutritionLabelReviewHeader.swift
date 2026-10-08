import ExerlyCore
import SwiftUI

struct NutritionLabelReviewHeader: View {
    let scan: NutritionLabelScan
    @State private var viewingPhoto = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ExCard(accent: true) {
            ExEyebrow("Review before saving", color: .exPrimaryText)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.item))
                : AnyLayout(HStackLayout(alignment: .top, spacing: ExSpacing.item))
            layout {
                if let image = UIImage(data: scan.imageData) {
                    Button { viewingPhoto = true } label: {
                        VStack(alignment: .leading, spacing: ExSpacing.small) {
                            Image(uiImage: image).resizable().scaledToFit().frame(width: 88, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: ExRadius.control))
                            Text("View photo").font(.exCaption).foregroundStyle(Color.exPrimaryText)
                        }
                    }.buttonStyle(.plain).accessibilityLabel("View original nutrition label")
                }
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    Text("Nutrition Facts").font(.exH3)
                    Text(basis).font(.exBody)
                    Text("Check the photo against every value below. Missing values stay unknown.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
            }
            if scan.reading.basis == .per100ml {
                Text("Enter how much 100 ml weighs in grams. Volume alone does not tell us its weight.")
                    .font(.exBody).foregroundStyle(Color.exPrimaryText)
            } else if scan.reading.basis == .serving, scan.reading.servingGrams == nil {
                Text("The serving's weight could not be read. Enter its weight in grams before saving.")
                    .font(.exBody).foregroundStyle(Color.exPrimaryText)
            }
            if !scan.reading.approximated.isEmpty || !scan.reading.unread.isEmpty {
                Text("Check these values").font(.exH3)
                ForEach(Nutrient.allCases.filter { scan.reading.approximated.contains($0) }, id: \.self) { nutrient in
                    Text("\(nutrient.name) was printed as less than \(TrainingFormat.number(scan.reading.amounts[nutrient] ?? 0)) \(nutrient.unit.rawValue). The field uses that upper bound; correct it or leave it unknown.")
                        .font(.exBody).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(scan.reading.unread.indices, id: \.self) { index in
                    Text("Could not read an amount: \(scan.reading.unread[index])").font(.exBody).fixedSize(horizontal: false, vertical: true)
                }
            }
            DisclosureGroup("Recognized text") {
                Text(scan.lines.joined(separator: "\n")).font(.exCaption).textSelection(.enabled)
            }
        }
        .sheet(isPresented: $viewingPhoto) {
            NavigationStack {
                ExScreen {
                    if let image = UIImage(data: scan.imageData) {
                        Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Original nutrition label photo")
                    }
                    Text(scan.lines.joined(separator: "\n")).font(.exBody).textSelection(.enabled)
                }
                .navigationTitle("Label photo").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { viewingPhoto = false } } }
            }
        }
    }

    private var basis: String {
        switch scan.reading.basis {
        case .per100g: "Printed amounts per 100 g"
        case .per100ml: "Printed amounts per 100 ml"
        case .serving: scan.reading.servingText.map { "Printed serving: \($0)" } ?? "Printed amounts per serving"
        }
    }
}
