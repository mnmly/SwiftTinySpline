import CTinySpline
import simd

/// A local coordinate frame along a curve: a position plus an orthonormal
/// (tangent, normal, binormal) basis. Produced by ``BSpline/computeRMF(at:firstNormal:)``.
public struct Frame: Equatable, Sendable {
    public let position: SIMD3<Double>
    public let tangent: SIMD3<Double>
    public let normal: SIMD3<Double>
    public let binormal: SIMD3<Double>

    public init(
        position: SIMD3<Double>,
        tangent: SIMD3<Double>,
        normal: SIMD3<Double>,
        binormal: SIMD3<Double>
    ) {
        self.position = position
        self.tangent = tangent
        self.normal = normal
        self.binormal = binormal
    }

    init(_ frame: tinyspline.Frame) {
        self.init(
            position: SIMD3(frame.position()),
            tangent: SIMD3(frame.tangent()),
            normal: SIMD3(frame.normal()),
            binormal: SIMD3(frame.binormal())
        )
    }
}
