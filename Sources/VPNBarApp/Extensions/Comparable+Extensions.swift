import Foundation

extension Comparable {
    /// Clamps value to the specified range.
    /// - Parameter range: Closed range to clamp value to.
    /// - Returns: Value clamped to the range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


