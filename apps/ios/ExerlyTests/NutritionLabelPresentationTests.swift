import ExerlyCore
import UIKit
import XCTest
@testable import Exerly

@MainActor
final class NutritionLabelPresentationTests: XCTestCase {
    func testVisionReadsARealSyntheticNutritionFactsImageAndPreservesUnknownsAndZero() async throws {
        let data = labelImage()
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "synthetic-nutrition-facts"
        attachment.lifetime = .keepAlways
        add(attachment)
        let scan = try await NutritionLabelRecognition.recognize(data)
        XCTAssertEqual(scan.reading.basis, .serving, scan.lines.joined(separator: "\n"))
        XCTAssertEqual(scan.reading.servingGrams, 55, scan.lines.joined(separator: "\n"))
        XCTAssertEqual(scan.reading.amounts[.energy], 230, scan.lines.joined(separator: "\n"))
        XCTAssertEqual(scan.reading.amounts[.protein], 3)
        XCTAssertEqual(scan.reading.amounts[.carbohydrate], 37)
        XCTAssertEqual(scan.reading.amounts[.fat], 8)
        XCTAssertEqual(scan.reading.amounts[.sodium], 0)
        XCTAssertNil(scan.reading.amounts[.vitaminD])
        XCTAssertTrue(scan.reading.approximated.contains(.fiber), scan.lines.joined(separator: "\n"))
        XCTAssertTrue(scan.reading.unread.contains { $0.contains("potassium") })
        XCTAssertNotNil(UIImage(data: scan.imageData))
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionFoodDraft(store: store, label: scan.reading)
        XCTAssertTrue(store.foods.isEmpty, "Reading and reviewing must not save a food")
        XCTAssertEqual(draft.basis, .perServing)
        XCTAssertEqual(draft.labelGrams.text, "55")
        draft.name = "Reviewed cereal"
        let food = try XCTUnwrap(draft.save())
        XCTAssertEqual(food.source, .custom)
        XCTAssertEqual(food.per100g, scan.reading.per100g)
        XCTAssertEqual(food.servings.first?.grams, 55)
        XCTAssertNil(food.per100g[.vitaminD])
        XCTAssertEqual(food.per100g[.sodium], 0)
    }

    func testVisionJoinsSeparatedNutrientAmountsAndIgnoresDailyPercentages() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 1100, height: 1100), format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1100, height: 1100))
            let rows = [
                ["Nutrition Facts", "", ""], ["Serving size 1 bar (45 g)", "", ""],
                ["Calories", "220", ""], ["Total Fat", "4 g", "5%"], ["Sodium", "230 mg", "10%"],
                ["Total Carbohydrate", "30 g", "11%"], ["Protein", "12 g", "24%"]
            ]
            for (index, row) in rows.enumerated() {
                for (column, text) in row.enumerated() {
                    let point = CGPoint(x: [50, 690, 940][column], y: 50 + index * 140)
                    (text as NSString).draw(at: point, withAttributes: [.font: UIFont.systemFont(ofSize: 44), .foregroundColor: UIColor.black])
                }
            }
        }
        let scan = try await NutritionLabelRecognition.recognize(data)
        let explanation = scan.lines.joined(separator: "\n")
        XCTAssertEqual(scan.reading.servingGrams, 45, explanation)
        XCTAssertEqual(scan.reading.amounts[.energy], 220, explanation)
        XCTAssertEqual(scan.reading.amounts[.fat], 4, explanation)
        XCTAssertEqual(scan.reading.amounts[.sodium], 230, explanation)
        XCTAssertEqual(scan.reading.amounts[.carbohydrate], 30, explanation)
        XCTAssertEqual(scan.reading.amounts[.protein], 12, explanation)
    }

    func testVolumeLabelsRequireTheWeightOfThePrintedAmountAndNeverAssumeWaterDensity() throws {
        let reading = try XCTUnwrap(NutritionLabel.read([
            "Nutrition per 100 ml", "Serving size 1 cup (240 g)", "Energy 200 kJ", "Fat 0 g", "Protein 2 g"
        ]))
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionFoodDraft(store: store, label: reading)
        draft.name = "Measured drink"
        XCTAssertEqual(draft.basis, .perServing)
        XCTAssertTrue(draft.labelGrams.text.isEmpty, "The printed 240 g serving is not the weight of 100 ml")
        XCTAssertNil(draft.save())
        XCTAssertTrue(store.foods.isEmpty)
        draft.labelGrams.text = "107"
        let saved = try XCTUnwrap(draft.save())
        XCTAssertEqual(saved.per100g, try ExerlyCore.Food.per100g(fromLabel: reading.amounts, servingGrams: 107))
        XCTAssertNil(saved.volume, "No volume basis was confirmed")
    }

    func testPer100gLabelCanBeCorrectedWithoutDoubleScalingOrInventingMissingValues() throws {
        let reading = try XCTUnwrap(NutritionLabel.read(["Nutrition per 100 g", "Energy 420 kcal", "Fat 0 g", "Protein 9 g"]))
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionFoodDraft(store: store, label: reading)
        draft.name = "Reviewed food"
        XCTAssertEqual(draft.basis, .per100g)
        draft.nutrients[.protein]?.text = "9,125"
        let saved = try XCTUnwrap(draft.save(locale: Locale(identifier: "de_DE")))
        XCTAssertEqual(saved.per100g[.energy], 420)
        XCTAssertEqual(saved.per100g[.protein], 9.125)
        XCTAssertEqual(saved.per100g[.fat], 0)
        XCTAssertNil(saved.per100g[.carbohydrate])
        XCTAssertTrue(saved.servings.isEmpty)
    }

    func testPerServingKilojouleLabelKeepsItsPrintedWeightBasis() throws {
        let reading = try XCTUnwrap(NutritionLabel.read([
            "Nutrition Facts", "Serving size 1 bar (50 g)", "Amount per serving",
            "Energy 837 kJ / 200 kcal", "Fat 8 g", "Carbohydrate 25 g", "Protein 7 g"
        ]))
        XCTAssertEqual(reading.basis, .serving, "An energy unit must not replace the printed serving basis")
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionFoodDraft(store: store, label: reading)
        draft.name = "Reviewed per-serving bar"
        let saved = try XCTUnwrap(draft.save())
        XCTAssertEqual(saved.per100g[.energy], 400, "200 kcal per 50 g is 400 kcal per 100 g")
    }

    func testUnreadableAndOversizedImagesHaveManualRecoveryErrors() async throws {
        for data in [Data(), Data("not an image".utf8), Data(repeating: 0, count: NutritionLabelRecognition.maximumBytes + 1)] {
            do {
                _ = try await NutritionLabelRecognition.recognize(data)
                XCTFail("An invalid image must not produce a label")
            } catch { XCTAssertTrue(error is NutritionLabelRecognitionError) }
        }
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        do {
            _ = try await NutritionLabelRecognition.recognize(blank)
            XCTFail("A blank photo must offer a manual path")
        } catch { XCTAssertEqual(error as? NutritionLabelRecognitionError, .noLabel) }
    }

    func testCancelledAndReplacedScansCannotRestoreAnOldPhotoOrError() async throws {
        let gate = LabelRecognitionGate()
        let scanner = NutritionLabelScanner { data in try await gate.read(data) }
        let reading = try XCTUnwrap(NutritionLabel.read(["Calories 50"]))
        let first = NutritionLabelScan(imageData: Data([1]), lines: ["first"], reading: reading)
        let second = NutritionLabelScan(imageData: Data([2]), lines: ["second"], reading: reading)
        scanner.read(Data([1]))
        try await waitForRequests(1, gate: gate)
        scanner.read(Data([2]))
        try await waitForRequests(2, gate: gate)
        await gate.complete(2, result: .success(second))
        for _ in 0..<100 where scanner.isReading { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(scanner.result?.id, second.id)
        await gate.complete(1, result: .failure(NutritionLabelRecognitionError.noLabel))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(scanner.result?.id, second.id)
        XCTAssertNil(scanner.error)
        scanner.read(Data([3]))
        try await waitForRequests(1, gate: gate)
        scanner.cancel()
        await gate.complete(3, result: .success(first))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(scanner.result)
        XCTAssertNil(scanner.error)
        XCTAssertFalse(scanner.isReading)
    }

    private func waitForRequests(_ count: Int, gate: LabelRecognitionGate) async throws {
        for _ in 0..<100 {
            if await gate.count == count { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Recognition request did not start")
    }

    private func labelImage() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1420), format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1420))
            let rows = ["Nutrition Facts", "Serving size 2/3 cup (55 g)", "Amount per serving", "Calories 230",
                        "Total Fat 8 g", "Saturated Fat 0 g", "Sodium 0 mg", "Total Carbohydrate 37 g",
                        "Dietary Fiber <1 g", "Protein 3 g", "Potassium"]
            for (index, row) in rows.enumerated() {
                let font = UIFont.systemFont(ofSize: index == 0 ? 78 : 44, weight: index == 0 || index == 3 ? .bold : .regular)
                (row as NSString).draw(at: CGPoint(x: 50, y: 40 + index * 116), withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
        }
    }
}

private actor LabelRecognitionGate {
    var waiting: [UInt8: CheckedContinuation<NutritionLabelScan, Error>] = [:]
    var count: Int { waiting.count }

    func read(_ data: Data) async throws -> NutritionLabelScan {
        try await withCheckedThrowingContinuation { waiting[data.first ?? 0] = $0 }
    }

    func complete(_ id: UInt8, result: Result<NutritionLabelScan, Error>) { waiting.removeValue(forKey: id)?.resume(with: result) }
}
