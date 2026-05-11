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

    @Test func optionalMetricBoundaries() {
        #expect(ColorThresholds.color(for: 0.19, metric: .bodyTemperatureDeviation) == .systemGreen)
        #expect(ColorThresholds.color(for: -0.5, metric: .bodyTemperatureDeviation) == .systemOrange)
        #expect(ColorThresholds.color(for: 0.51, metric: .bodyTemperatureDeviation) == .systemRed)
        #expect(ColorThresholds.color(for: 84.9, metric: .sleepEfficiency) == .systemOrange)
        #expect(ColorThresholds.color(for: 85, metric: .sleepEfficiency) == .systemGreen)
        #expect(ColorThresholds.color(for: 47, metric: .cardiovascularAge, baseline: 42) == .systemOrange)
        #expect(ColorThresholds.color(for: 48, metric: .cardiovascularAge, baseline: 42) == .systemRed)
    }

    @Test func categoricalMetricColors() {
        #expect(ColorThresholds.color(forCategory: "restored", metric: .dailyStress) == .systemGreen)
        #expect(ColorThresholds.color(forCategory: "normal", metric: .dailyStress) == .systemOrange)
        #expect(ColorThresholds.color(forCategory: "stressful", metric: .dailyStress) == .systemRed)
        #expect(ColorThresholds.color(forCategory: "limited", metric: .resilience) == .systemRed)
        #expect(ColorThresholds.color(forCategory: "adequate", metric: .resilience) == .systemOrange)
        #expect(ColorThresholds.color(forCategory: "solid", metric: .resilience) == .systemGreen)
    }
}
