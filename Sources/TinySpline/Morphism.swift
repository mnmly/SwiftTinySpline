import CTinySpline

/// A blend between two B-splines.
///
/// Evaluating a `Morphism` at `t ∈ [0, 1]` produces a curve interpolated
/// between the origin (`t = 0`) and target (`t = 1`). Create one with
/// ``BSpline/morph(to:epsilon:)``.
///
/// This is a reference type because the underlying C++ `Morphism` keeps mutable
/// internal buffers that it reuses across evaluations; it is therefore **not**
/// `Sendable`. Create one per isolation domain if you need concurrent morphing.
public final class Morphism {
    /// Owned heap pointer to the C++ `Morphism` (freed in `deinit`).
    private let handle: UnsafeMutablePointer<tinyspline.Morphism>

    init(origin: BSpline, target: BSpline, epsilon: Double) throws {
        let ptr = try Interop.checked { status in
            tinyspline_swift.makeMorphism(origin.spline, target.spline, epsilon, &status)
        }
        guard let ptr else {
            throw TinySplineError(code: 1, message: "failed to create Morphism")
        }
        self.handle = ptr
    }

    deinit {
        tinyspline_swift.freeMorphism(handle)
    }

    /// Evaluate the blend at `t` (`0` = origin, `1` = target).
    public func eval(_ t: Double) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.morphismEval(handle, t, &status)
        })
    }

    /// Shorthand for ``eval(_:)`` — `try morphism(0.5)`.
    public func callAsFunction(_ t: Double) throws -> BSpline {
        try eval(t)
    }
}
