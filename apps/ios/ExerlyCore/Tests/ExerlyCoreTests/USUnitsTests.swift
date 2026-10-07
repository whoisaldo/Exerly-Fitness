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
