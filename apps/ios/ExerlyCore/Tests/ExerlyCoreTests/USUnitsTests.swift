import Foundation
import Testing
@testable import ExerlyCore

@Suite struct USUnitsTests {
    @Test func waterInFluidOuncesStoresAsWholeMillilitresAndComesBack() {
        #expect(USUnits.wholeMilliliters(fluidOunces: 8) == 237)
        #expect(USUnits.wholeMilliliters(fluidOunces: 16.9) == 500)
        for ounces in 1...200 {
            let stored = USUnits.wholeMilliliters(fluidOunces: Double(ounces))
            let shown = (USUnits.fluidOunces(milliliters: Double(stored)) * 10).rounded() / 10
            #expect(shown == Double(ounces), "\(ounces) fl oz")
        }
        #expect(abs(USUnits.milliliters(fluidOunces: 1) - 29.5735295625) < 1e-12)
    }

    @Test func foodInOuncesConvertsExactlyBothWays() {
        #expect(USUnits.grams(ounces: 16) == 453.592_37, "16 oz is exactly a pound")
        #expect(USUnits.grams(ounces: 1) == 28.349_523_125)
        for tenths in 1...1000 {
            let ounces = Double(tenths) / 10
            #expect(abs(USUnits.ounces(grams: USUnits.grams(ounces: ounces)) - ounces) < 1e-12)
        }
        #expect(USUnits.grams(ounces: 1) == ShortcutsJSON.grams["ounces"])
    }

    @Test func heightsConvertBothWaysAndCarryInchesToFeet() {
        #expect(abs(USUnits.centimeters(feet: 5, inches: 11) - 180.34) < 1e-9)
        #expect(USUnits.feetAndInches(centimeters: 180) == (5, 11))
        #expect(USUnits.feetAndInches(centimeters: 182.8) == (6, 0))
        #expect(USUnits.feetAndInches(centimeters: 180, inchStep: 0.5) == (5, 11))
        #expect(USUnits.feetAndInches(centimeters: 177.8, inchStep: 0.5) == (5, 10))
        for inches in 48...90 {
            let (feet, rest) = USUnits.feetAndInches(centimeters: USUnits.centimeters(feet: 0, inches: Double(inches)))
            #expect(feet * 12 + Int(rest) == inches)
        }
    }
}
