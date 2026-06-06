import CTinySpline
import CxxStdlib

/// Internal bridging helpers between Swift value types and the C++ layer.
///
/// All of these are `@inline(__always)` thin adapters; they exist so the public
/// wrapper stays readable and the conversion logic lives in exactly one place.
enum Interop {
    /// Convert a Swift `[Double]` into a C++ `std::vector<real>`.
    @inline(__always)
    static func realVector(_ values: [Double]) -> tinyspline_swift.RealVector {
        values.withUnsafeBufferPointer { buffer in
            tinyspline_swift.makeRealVector(buffer.baseAddress, buffer.count)
        }
    }

    /// Convert a C++ `std::vector<real>` into a Swift `[Double]`.
    @inline(__always)
    static func array(_ vector: tinyspline_swift.RealVector) -> [Double] {
        Array(vector)
    }

    /// Run a shim call that reports through a `Status` out-parameter, throwing
    /// `TinySplineError` if it failed.
    @inline(__always)
    static func checked<T>(
        _ body: (inout tinyspline_swift.Status) -> T
    ) throws -> T {
        var status = tinyspline_swift.Status()
        let result = body(&status)
        if status.code != 0 {
            throw TinySplineError(code: Int(status.code), message: String(status.message))
        }
        return result
    }
}
