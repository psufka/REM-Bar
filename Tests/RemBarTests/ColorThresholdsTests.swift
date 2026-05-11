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
        #expect(ColorThresholds.color(for: 89.9, metric: .deepSleep) == .systemOrange)
        #expect(ColorThresholds.color(for: 90, metric: .deepSleep) == .systemGreen)
        #expect(ColorThresholds.color(for: 419.9, metric: .totalSleep) == .systemOrange)
        #expect(ColorThresholds.color(for: 420, metric: .totalSleep) == .systemGreen)
        #expect(ColorThresholds.color(for: 47, metric: .cardiovascularAge, baseline: 42) == .systemOrange)
        #expect(ColorThresholds.color(for: 48, metric: .cardiovascularAge, baseline: 42) == .systemRed)
    }

    @Test func expandedMetricBoundaries() {
        #expect(ColorThresholds.color(for: 179.9, metric: .lightSleep) == .systemOrange)
        #expect(ColorThresholds.color(for: 180, metric: .lightSleep) == .systemGreen)
        #expect(ColorThresholds.color(for: 45, metric: .awakeTime) == .systemGreen)
        #expect(ColorThresholds.color(for: 75.1, metric: .awakeTime) == .systemRed)
        #expect(ColorThresholds.color(for: 14.2, metric: .averageBreath) == .systemGreen)
        #expect(ColorThresholds.color(for: 95, metric: .averageSpO2) == .systemGreen)
        #expect(ColorThresholds.color(for: 89.9, metric: .averageSpO2) == .systemRed)
        #expect(ColorThresholds.color(for: 5, metric: .breathingDisturbance) == .systemGreen)
        #expect(ColorThresholds.color(for: 15.1, metric: .breathingDisturbance) == .systemRed)
        #expect(ColorThresholds.color(for: 40, metric: .vo2Max) == .systemGreen)
    }

    @Test func categoricalMetricColors() {
        #expect(ColorThresholds.color(forCategory: "restored", metric: .dailyStress) == .systemGreen)
        #expect(ColorThresholds.color(forCategory: "normal", metric: .dailyStress) == .systemOrange)
        #expect(ColorThresholds.color(forCategory: "stressful", metric: .dailyStress) == .systemRed)
        #expect(ColorThresholds.color(forCategory: "limited", metric: .resilience) == .systemRed)
        #expect(ColorThresholds.color(forCategory: "adequate", metric: .resilience) == .systemOrange)
        #expect(ColorThresholds.color(forCategory: "solid", metric: .resilience) == .systemGreen)
        #expect(ColorThresholds.color(forCategory: "22:30-23:30", metric: .optimalBedtime) == .systemGreen)
        #expect(ColorThresholds.color(forCategory: "follow_optimal_bedtime", metric: .sleepTimeRecommendation) == .systemGreen)
    }
}
