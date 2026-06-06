/// An error raised by a TinySpline operation.
///
/// TinySpline's C++ core reports failures by throwing `std::exception`. Because
/// Swift cannot catch C++ exceptions, those throws are intercepted in a C++
/// shim and re-surfaced here as a normal Swift `Error`, so they integrate with
/// `do`/`catch` and never terminate the process.
public struct TinySplineError: Error, Equatable, Sendable {
    /// Non-zero status code reported by the underlying operation.
    public let code: Int
    /// Human-readable description of what went wrong.
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

extension TinySplineError: CustomStringConvertible {
    public var description: String {
        message.isEmpty ? "TinySplineError(\(code))" : message
    }
}
