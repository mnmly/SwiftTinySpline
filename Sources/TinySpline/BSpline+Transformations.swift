import CTinySpline
import CxxStdlib

extension BSpline {
    // MARK: - Transformations (each returns a new, independent spline)

    /// Insert knot `u` with multiplicity `n`, returning the refined spline.
    public func insertingKnot(_ u: Double, multiplicity n: Int = 1) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.insertKnot(spline, u, n, &status)
        })
    }

    /// Split the curve at knot `u` (inserts `u` up to the curve's order).
    public func split(at u: Double) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.split(spline, u, &status)
        })
    }

    /// Apply a tension factor (`1` = unchanged, `0` = straight lines between
    /// control points), returning the adjusted spline.
    public func tensioned(_ tension: Double) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.tension(spline, tension, &status)
        })
    }

    /// Decompose the curve into a sequence of Bézier curves.
    public func toBeziers() throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.toBeziers(spline, &status)
        })
    }

    /// Differentiate the curve `n` times.
    ///
    /// - Throws: ``TinySplineError`` if the curve is not `n`-times derivable
    ///   (e.g. discontinuities make a derivative undefined within `epsilon`).
    public func derivative(_ n: Int = 1, epsilon: Double = 1e-5) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.derive(spline, n, epsilon, &status)
        })
    }

    /// Elevate the degree of the curve by `amount`.
    public func elevatingDegree(by amount: Int, epsilon: Double = 1e-5) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.elevateDegree(spline, amount, epsilon, &status)
        })
    }

    /// Extract the sub-curve between knots `from` and `to`.
    public func subSpline(from: Double, to: Double) throws -> BSpline {
        BSpline(try Interop.checked { status in
            tinyspline_swift.subSpline(spline, from, to, &status)
        })
    }

    // MARK: - Serialization

    /// Serialize the curve to a JSON string.
    public func toJSON() throws -> String {
        String(try Interop.checked { status in
            tinyspline_swift.toJson(spline, &status)
        })
    }

    /// Write the curve to a JSON file at `path`.
    public func save(to path: String) throws {
        let p = std.string(path)
        try Interop.checked { status -> Void in
            tinyspline_swift.save(spline, p, &status)
        }
    }

    // MARK: - Spline framing

    /// Compute a rotation-minimizing frame at each knot in `knots`.
    ///
    /// - Parameters:
    ///   - knots: Knots (within ``domain``) at which to evaluate frames.
    ///   - firstNormal: Optional starting normal to seed the sequence.
    public func computeRMF(
        at knots: [Double],
        firstNormal: SIMD3<Double>? = nil
    ) throws -> [Frame] {
        let kv = Interop.realVector(knots)
        let n = firstNormal ?? .zero
        let seq = try Interop.checked { status in
            tinyspline_swift.computeRMF(
                spline, kv,
                firstNormal != nil, n.x, n.y, n.z,
                &status)
        }
        let size = Int(seq.size())
        var frames: [Frame] = []
        frames.reserveCapacity(size)
        for i in 0..<size {
            frames.append(Frame(seq.at(i)))
        }
        return frames
    }

    // MARK: - Reparametrization by arc length

    /// Compute chord lengths using the given `knots` as sample sites.
    public func chordLengths(at knots: [Double]) throws -> ChordLengths {
        let kv = Interop.realVector(knots)
        return ChordLengths(try Interop.checked { status in
            tinyspline_swift.chordLengthsByKnots(spline, kv, &status)
        })
    }

    /// Compute chord lengths from `numSamples` equidistant samples.
    public func chordLengths(numSamples: Int = 200) throws -> ChordLengths {
        ChordLengths(try Interop.checked { status in
            tinyspline_swift.chordLengthsBySamples(spline, numSamples, &status)
        })
    }

    // MARK: - Morphing

    /// Create a ``Morphism`` that blends this curve into `other`.
    public func morph(to other: BSpline, epsilon: Double = 1e-5) throws -> Morphism {
        try Morphism(origin: self, target: other, epsilon: epsilon)
    }
}

extension BSpline: CustomStringConvertible {
    public var description: String { String(spline.toString()) }
}
