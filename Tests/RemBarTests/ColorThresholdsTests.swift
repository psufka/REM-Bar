import AppKit
import Testing
@testable import REMBar

struct ColorThresholdsTests {
    @Test func sleepScoreBoundaries() {
        #expect(ColorThresholds.color(for: 84.9) == .systemOrange)
        #expect(ColorThresholds.color(for: 85) == .systemGreen)
        #expect(ColorThresholds.color(for: 69.9) == .systemRed)
        #expect(ColorThresholds.color(for: 70) == .systemOrange)
    }
}
