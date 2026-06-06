import CTinySpline

/// How the knot vector of a freshly created ``BSpline`` is set up.
public enum SplineType: Int, Sendable, CaseIterable {
    /// Uniform knot vector; the spline does not touch its end points.
    case opened = 0
    /// Clamped knot vector; the spline passes through its first and last
    /// control points. This is the most common choice.
    case clamped = 1
    /// Knot vector arranged so the spline is a sequence of Bézier curves.
    case beziers = 2

    @inline(__always)
    var cxx: tinyspline_swift.SplineType {
        tinyspline_swift.SplineType(rawValue: Int32(rawValue))!
    }
}

/// The interval of knots over which a ``BSpline`` is defined.
public struct Domain: Equatable, Sendable {
    public let min: Double
    public let max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }

    /// Whether `knot` lies within `[min, max]`.
    public func contains(_ knot: Double) -> Bool {
        knot >= min && knot <= max
    }

    /// Clamp `knot` into `[min, max]`.
    public func clamp(_ knot: Double) -> Double {
        Swift.min(Swift.max(knot, min), max)
    }
}
