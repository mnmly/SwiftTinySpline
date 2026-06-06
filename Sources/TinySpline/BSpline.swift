import CTinySpline
import CxxStdlib
import simd

/// A B-spline / NURBS curve of arbitrary degree and dimensionality.
///
/// `BSpline` is a Swift value type wrapping TinySpline's C++ `BSpline`. It has
/// deep-copy value semantics: copying a `BSpline` (including passing it across
/// an actor boundary) produces an independent curve, which is why it is safe to
/// mark `Sendable`. All operations that can fail are `throws`; a failure never
/// terminates the process.
///
/// ```swift
/// let curve = try BSpline(
///     controlPoints: [-1.0, 0, 1, 1, 2, 0],
///     dimension: 2)
/// let mid = try curve.eval(0.5).point2   // SIMD2<Double>
/// let path = try curve.sample(64)        // [Double], flattened x,y pairs
/// ```
public struct BSpline: @unchecked Sendable {
    /// The wrapped C++ value. Mutated in place only by `mutating` members; all
    /// public mutation goes through copy-returning C++ shims, preserving value
    /// semantics.
    var spline: tinyspline.BSpline

    init(_ spline: tinyspline.BSpline) {
        self.spline = spline
    }

    // MARK: - Initializers

    /// Create an (uninitialized) spline with `numControlPoints` control points.
    ///
    /// The control points are zeroed; set them via ``controlPoints`` afterward.
    ///
    /// - Throws: ``TinySplineError`` if `degree >= numControlPoints`, if
    ///   `dimension == 0`, or if the requested ``SplineType`` is incompatible
    ///   with the given sizes.
    public init(
        numControlPoints: Int,
        dimension: Int = 2,
        degree: Int = 3,
        type: SplineType = .clamped
    ) throws {
        self.spline = try Interop.checked { status in
            tinyspline_swift.makeBSpline(
                numControlPoints, dimension, degree, type.cxx, &status)
        }
    }

    /// Create a clamped spline from a flattened list of control points.
    ///
    /// - Parameters:
    ///   - controlPoints: Control points flattened row-major, e.g. for 2-D
    ///     `[x0, y0, x1, y1, …]`. Count must be a multiple of `dimension`.
    ///   - dimension: Components per control point (2 for x/y, 3 for x/y/z, …).
    ///   - degree: Degree of the curve (default `3`, cubic).
    ///   - type: Knot-vector layout (default ``SplineType/clamped``).
    /// - Throws: ``TinySplineError`` if the sizes are inconsistent.
    public init(
        controlPoints: [Double],
        dimension: Int = 2,
        degree: Int = 3,
        type: SplineType = .clamped
    ) throws {
        guard dimension > 0 else {
            throw TinySplineError(code: -2, message: "dimension must be > 0")
        }
        guard controlPoints.count % dimension == 0 else {
            throw TinySplineError(
                code: -10,
                message: "controlPoints.count (\(controlPoints.count)) is not a multiple of dimension (\(dimension))")
        }
        let count = controlPoints.count / dimension
        var spline = try Interop.checked { status in
            tinyspline_swift.makeBSpline(count, dimension, degree, type.cxx, &status)
        }
        let cp = Interop.realVector(controlPoints)
        spline = try Interop.checked { status in
            tinyspline_swift.setControlPoints(spline, cp, &status)
        }
        self.spline = spline
    }

    // MARK: - Factory methods

    /// Interpolate the given points with a natural cubic spline (zero curvature
    /// at the end points).
    public static func interpolatingCubicNatural(
        points: [Double],
        dimension: Int
    ) throws -> BSpline {
        let pts = Interop.realVector(points)
        return BSpline(try Interop.checked { status in
            tinyspline_swift.interpolateCubicNatural(pts, dimension, &status)
        })
    }

    /// Interpolate the given points with a centripetal Catmull–Rom spline.
    ///
    /// - Parameters:
    ///   - points: Points to interpolate, flattened row-major.
    ///   - dimension: Components per point (2 for x/y, 3 for x/y/z, …).
    ///   - alpha: Parametrization exponent (`0.5` = centripetal, the default).
    ///   - first: Optional virtual point prepended to control the start tangent.
    ///   - last: Optional virtual point appended to control the end tangent.
    ///   - epsilon: Distance under which consecutive points are treated as equal.
    public static func interpolatingCatmullRom(
        points: [Double],
        dimension: Int,
        alpha: Double = 0.5,
        first: [Double]? = nil,
        last: [Double]? = nil,
        epsilon: Double = 1e-5
    ) throws -> BSpline {
        let pts = Interop.realVector(points)
        let firstV = Interop.realVector(first ?? [])
        let lastV = Interop.realVector(last ?? [])
        return BSpline(try Interop.checked { status in
            tinyspline_swift.interpolateCatmullRom(
                pts, dimension, alpha,
                first != nil, firstV,
                last != nil, lastV,
                epsilon, &status)
        })
    }

    /// Parse a spline from its JSON representation.
    public init(json: String) throws {
        let s = std.string(json)
        self.spline = try Interop.checked { status in
            tinyspline_swift.parseJson(s, &status)
        }
    }

    /// Load a spline from a JSON file at `path`.
    public init(contentsOfFile path: String) throws {
        let s = std.string(path)
        self.spline = try Interop.checked { status in
            tinyspline_swift.load(s, &status)
        }
    }

    // MARK: - Attributes

    /// Degree of the curve.
    public var degree: Int { Int(spline.degree()) }

    /// Order of the curve (`degree + 1`).
    public var order: Int { Int(spline.order()) }

    /// Components per control point.
    public var dimension: Int { Int(spline.dimension()) }

    /// Number of control points.
    public var count: Int { Int(spline.numControlPoints()) }

    /// The knot interval over which the curve is defined.
    public var domain: Domain {
        let d = spline.domain()
        return Domain(min: d.min(), max: d.max())
    }

    /// Whether the curve is closed (first and last points coincide).
    public func isClosed(epsilon: Double = 1e-5) -> Bool {
        spline.isClosed(epsilon)
    }

    // MARK: - Control points & knots

    /// The control points, flattened row-major. Setting validates the count.
    public var controlPoints: [Double] {
        get { Interop.array(spline.controlPoints()) }
        set {
            // Non-throwing setter: invalid sizes are clamped out by ignoring
            // the assignment. Use `setControlPoints(_:)` to detect errors.
            try? setControlPoints(newValue)
        }
    }

    /// Replace the control points, throwing if the count is inconsistent.
    public mutating func setControlPoints(_ points: [Double]) throws {
        let cp = Interop.realVector(points)
        spline = try Interop.checked { status in
            tinyspline_swift.setControlPoints(spline, cp, &status)
        }
    }

    /// The knot vector. Setting validates monotonicity and length.
    public var knots: [Double] {
        get { Interop.array(spline.knots()) }
        set { try? setKnots(newValue) }
    }

    /// Replace the knot vector, throwing if it is decreasing or the wrong length.
    public mutating func setKnots(_ knots: [Double]) throws {
        let kv = Interop.realVector(knots)
        spline = try Interop.checked { status in
            tinyspline_swift.setKnots(spline, kv, &status)
        }
    }

    /// Set the knot at `index`, throwing on an out-of-range index or a
    /// resulting non-monotonic knot vector.
    public mutating func setKnot(at index: Int, to knot: Double) throws {
        spline = try Interop.checked { status in
            tinyspline_swift.setKnotAt(spline, index, knot, &status)
        }
    }

    /// The control point at `index` as a 2-D vector.
    public func controlPoint2(at index: Int) -> SIMD2<Double> {
        SIMD2(spline.controlPointVec2At(index))
    }

    /// The control point at `index` as a 3-D vector.
    public func controlPoint3(at index: Int) -> SIMD3<Double> {
        SIMD3(spline.controlPointVec3At(index))
    }

    // MARK: - Evaluation

    /// Evaluate the curve at knot `u` (within ``domain``).
    ///
    /// - Throws: ``TinySplineError`` if `u` lies outside ``domain``.
    public func eval(_ u: Double) throws -> DeBoorNet {
        guard domain.contains(u) else {
            throw TinySplineError(
                code: -4,
                message: "knot \(u) is outside domain [\(domain.min), \(domain.max)]")
        }
        return DeBoorNet(spline.eval(u))
    }

    /// Evaluate the curve at `u`, clamping `u` into ``domain`` first (never throws).
    public func evalClamped(_ u: Double) -> DeBoorNet {
        DeBoorNet(spline.eval(domain.clamp(u)))
    }

    /// Evaluate the curve at every knot in `knots`, returning flattened points.
    public func evalAll(_ knots: [Double]) throws -> [Double] {
        let kv = Interop.realVector(knots)
        return Interop.array(try Interop.checked { status in
            tinyspline_swift.evalAll(spline, kv, &status)
        })
    }

    /// Sample the curve at `count` equidistant knots (in parameter space),
    /// returning flattened points. Pass `0` to let TinySpline choose a count.
    public func sample(_ count: Int = 0) -> [Double] {
        Interop.array(spline.sample(count))
    }

    // MARK: - call-as-function sugar

    /// Shorthand for ``eval(_:)`` — `try curve(0.5)`.
    public func callAsFunction(_ u: Double) throws -> DeBoorNet {
        try eval(u)
    }
}
