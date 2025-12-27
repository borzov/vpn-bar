import Foundation

extension Comparable {
    /// Ограничивает значение указанным диапазоном.
    /// - Parameter range: Закрытый диапазон для ограничения значения.
    /// - Returns: Значение, ограниченное диапазоном.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


