import CoreGraphics

enum PopoverLayoutMetrics {
    static let popoverWidth: CGFloat = 540
    static let cardHeight: CGFloat = 126
    static let cardSpacing: CGFloat = 10
    static let contentPadding: CGFloat = 14
    static let contentSpacing: CGFloat = 12
    static let footerControlsHeight: CGFloat = 24
    static let refreshTextHeight: CGFloat = 14
    static let dividerHeight: CGFloat = 1
    static let screenBottomMargin: CGFloat = 8
    static let minimumPopoverHeight: CGFloat = 380

    static var footerReservedHeight: CGFloat {
        contentPadding * 2
            + contentSpacing * 3
            + dividerHeight
            + footerControlsHeight
            + refreshTextHeight
    }

    static func columnCount(for visibleMetricCount: Int) -> Int {
        switch visibleMetricCount {
        case ...1:
            return 1
        case 2:
            return 2
        default:
            return 3
        }
    }

    static func rowCount(for visibleMetricCount: Int, columns: Int) -> Int {
        max(1, Int(ceil(Double(visibleMetricCount) / Double(columns))))
    }

    static func gridHeight(for rows: Int) -> CGFloat {
        CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * cardSpacing
    }
}
