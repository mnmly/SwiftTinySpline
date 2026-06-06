import CTinySpline
import simd

/// The result of evaluating a ``BSpline`` at a single knot.
///
/// Returned by ``BSpline/eval(_:)``. Besides the evaluated point(s), it exposes
/// the intermediate state of De Boor's algorithm (knot, span index,
/// multiplicity, …), which is useful when working at knot discontinuities.
///
/// This is a value type with deep-copy semantics over the underlying C++
/// object, hence safe to pass across concurrency domains.
public struct DeBoorNet: @unchecked Sendable {
    private var net: tinyspline.DeBoorNet

    init(_ net: tinyspline.DeBoorNet) {
        self.net = net
    }

    /// The knot this net was evaluated at.
    public var knot: Double { net.knot() }

    /// Index of the knot span containing ``knot``.
    public var index: Int { Int(net.index()) }

    /// Multiplicity of ``knot`` within the spline's knot vector.
    public var multiplicity: Int { Int(net.multiplicity()) }

    /// Number of knot insertions performed during evaluation.
    public var numInsertions: Int { Int(net.numInsertions()) }

    /// Dimensionality of the evaluated point(s).
    public var dimension: Int { Int(net.dimension()) }

    /// The points of the underlying De Boor net (flattened, row-major).
    public var points: [Double] { Interop.array(net.points()) }

    /// The evaluated result(s), flattened. For most splines this is a single
    /// point; at a discontinuity it may contain two.
    public var result: [Double] { Interop.array(net.result()) }

    /// The first evaluated point as a 2-D vector (missing components are `0`).
    public var point2: SIMD2<Double> { SIMD2(net.resultVec2(0)) }

    /// The first evaluated point as a 3-D vector (missing components are `0`).
    public var point3: SIMD3<Double> { SIMD3(net.resultVec3(0)) }

    /// The first evaluated point as a 4-D vector (missing components are `0`).
    public var point4: SIMD4<Double> { SIMD4(net.resultVec4(0)) }
}

extension DeBoorNet: CustomStringConvertible {
    public var description: String { String(net.toString()) }
}
