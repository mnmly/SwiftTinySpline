import CTinySpline

/// Arc-length reparametrization data for a ``BSpline``.
///
/// Produced by ``BSpline/chordLengths(at:)`` / ``BSpline/chordLengths(numSamples:)``.
/// Lets you map between curve length, normalized `t ∈ [0, 1]`, and knot values —
/// useful for moving along a curve at constant speed.
///
/// Value type with deep-copy semantics over the underlying C++ object.
public struct ChordLengths: @unchecked Sendable {
    private var lengths: tinyspline.ChordLengths

    init(_ lengths: tinyspline.ChordLengths) {
        self.lengths = lengths
    }

    /// The spline these chord lengths were computed for.
    public var spline: BSpline { BSpline(lengths.spline()) }

    /// The knots at which lengths were sampled.
    public var knots: [Double] { Interop.array(lengths.knots()) }

    /// The accumulated chord length at each sampled knot.
    public var values: [Double] { Interop.array(lengths.values()) }

    /// Number of samples.
    public var count: Int { Int(lengths.size()) }

    /// Total arc length of the curve.
    public var arcLength: Double { lengths.arcLength() }

    /// The knot whose arc length from the start is `length`.
    public func knot(forLength length: Double) throws -> Double {
        try Interop.checked { status in
            tinyspline_swift.lengthToKnot(lengths, length, &status)
        }
    }

    /// The knot at normalized arc-length position `t ∈ [0, 1]`.
    public func knot(forT t: Double) throws -> Double {
        try Interop.checked { status in
            tinyspline_swift.tToKnot(lengths, t, &status)
        }
    }
}

extension ChordLengths: CustomStringConvertible {
    public var description: String { String(lengths.toString()) }
}
