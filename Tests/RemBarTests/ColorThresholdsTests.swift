import AppKit
import XCTest
@testable import REMBar

final class ColorThresholdsTests: XCTestCase {
    func testSleepScoreBoundaries() {
        XCTAssertEqual(ColorThresholds.color(for: 84.9), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 85), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 69.9), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: 70), .systemOrange)
    }

    func testThresholdOverrideChangesMetricColor() {
        let overrides: [BarMetric: MetricThresholdOverride] = [
            .sleepScore: MetricThresholdOverride(direction: .higherIsBetter, green: 95, orange: 80),
            .sleepDebt: MetricThresholdOverride(direction: .lowerIsBetter, green: 15, orange: 45),
            .bodyTemperatureDeviation: MetricThresholdOverride(direction: .closerToZeroIsBetter, green: 0.1, orange: 0.3),
        ]

        XCTAssertEqual(ColorThresholds.color(for: 85, metric: .sleepScore, thresholdOverrides: overrides), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 60, metric: .sleepDebt, thresholdOverrides: overrides), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: -0.2, metric: .bodyTemperatureDeviation, thresholdOverrides: overrides), .systemOrange)
    }

    func testOptionalMetricBoundaries() {
        XCTAssertEqual(ColorThresholds.color(for: 0.19, metric: .bodyTemperatureDeviation), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: -0.5, metric: .bodyTemperatureDeviation), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 0.51, metric: .bodyTemperatureDeviation), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: 84.9, metric: .sleepEfficiency), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 85, metric: .sleepEfficiency), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 89.9, metric: .deepSleep), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 90, metric: .deepSleep), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 419.9, metric: .totalSleep), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 420, metric: .totalSleep), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 30, metric: .sleepDebt), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 90.1, metric: .sleepDebt), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: 47, metric: .cardiovascularAge, baseline: 42), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 48, metric: .cardiovascularAge, baseline: 42), .systemRed)
    }

    func testExpandedMetricBoundaries() {
        XCTAssertEqual(ColorThresholds.color(for: 179.9, metric: .lightSleep), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(for: 180, metric: .lightSleep), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 45, metric: .awakeTime), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 75.1, metric: .awakeTime), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: 14.2, metric: .averageBreath), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 95, metric: .averageSpO2), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 89.9, metric: .averageSpO2), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: 5, metric: .breathingDisturbance), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(for: 15.1, metric: .breathingDisturbance), .systemRed)
        XCTAssertEqual(ColorThresholds.color(for: 40, metric: .vo2Max), .systemGreen)
    }

    func testCategoricalMetricColors() {
        XCTAssertEqual(ColorThresholds.color(forCategory: "restored", metric: .dailyStress), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(forCategory: "normal", metric: .dailyStress), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(forCategory: "stressful", metric: .dailyStress), .systemRed)
        XCTAssertEqual(ColorThresholds.color(forCategory: "limited", metric: .resilience), .systemRed)
        XCTAssertEqual(ColorThresholds.color(forCategory: "adequate", metric: .resilience), .systemOrange)
        XCTAssertEqual(ColorThresholds.color(forCategory: "solid", metric: .resilience), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(forCategory: "22:30-23:30", metric: .optimalBedtime), .systemGreen)
        XCTAssertEqual(ColorThresholds.color(forCategory: "follow_optimal_bedtime", metric: .sleepTimeRecommendation), .systemGreen)
    }
}
