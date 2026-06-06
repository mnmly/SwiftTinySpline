import CTinySpline
import simd

/// Conversions from TinySpline's C++ vector types to Swift `SIMD` values.
///
/// The public API hands back `SIMD2/3/4<Double>` so callers get Swift's native
/// vector math (`dot`, `cross`, `length`, operators, …) for free instead of a
/// bespoke wrapper.
extension SIMD2 where Scalar == Double {
    init(_ v: tinyspline.Vec2) { self.init(v.x(), v.y()) }
}

extension SIMD3 where Scalar == Double {
    init(_ v: tinyspline.Vec3) { self.init(v.x(), v.y(), v.z()) }
}

extension SIMD4 where Scalar == Double {
    init(_ v: tinyspline.Vec4) { self.init(v.x(), v.y(), v.z(), v.w()) }
}
