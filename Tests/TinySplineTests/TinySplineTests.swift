import Testing
import simd
@testable import TinySpline

@Suite("BSpline construction & attributes")
struct ConstructionTests {
    @Test("Construct from control points")
    func fromControlPoints() throws {
        let curve = try BSpline(
            controlPoints: [-1.0, 0, -0.5, 1, 0.5, -1, 1, 0],
            dimension: 2,
            degree: 3)
        #expect(curve.dimension == 2)
        #expect(curve.degree == 3)
        #expect(curve.order == 4)
        #expect(curve.count == 4)
        #expect(curve.controlPoints.count == 8)
    }

    @Test("Non-multiple control point count throws")
    func badControlPointCount() {
        #expect(throws: TinySplineError.self) {
            _ = try BSpline(controlPoints: [0, 0, 1], dimension: 2)
        }
    }

    @Test("degree >= numControlPoints throws")
    func degreeTooHigh() {
        #expect(throws: TinySplineError.self) {
            _ = try BSpline(numControlPoints: 3, dimension: 2, degree: 5)
        }
    }

    @Test("Clamped domain is [0, 1]")
    func domain() throws {
        let curve = try BSpline(controlPoints: [0, 0, 1, 1, 2, 0, 3, 1], dimension: 2)
        #expect(curve.domain.min == 0)
        #expect(curve.domain.max == 1)
    }
}

@Suite("Evaluation")
struct EvaluationTests {
    func quadrant() throws -> BSpline {
        // A clamped cubic; endpoints are interpolated.
        try BSpline(controlPoints: [-1, 0, -0.5, 1, 0.5, -1, 1, 0], dimension: 2)
    }

    @Test("Endpoints are interpolated for clamped splines")
    func endpoints() throws {
        let curve = try quadrant()
        let start = try curve.eval(0).point2
        let end = try curve.eval(1).point2
        #expect(Swift.abs(start.x - (-1)) < 1e-9)
        #expect(Swift.abs(start.y - 0) < 1e-9)
        #expect(Swift.abs(end.x - 1) < 1e-9)
        #expect(Swift.abs(end.y - 0) < 1e-9)
    }

    @Test("eval out of domain throws, evalClamped does not")
    func outOfDomain() throws {
        let curve = try quadrant()
        #expect(throws: TinySplineError.self) { _ = try curve.eval(2.0) }
        let clamped = curve.evalClamped(2.0).point2
        let end = try curve.eval(1).point2
        #expect(clamped == end)
    }

    @Test("callAsFunction matches eval")
    func callable() throws {
        let curve = try quadrant()
        #expect(try curve(0.3).point2 == (try curve.eval(0.3).point2))
    }

    @Test("sample returns flattened points")
    func sample() throws {
        let curve = try quadrant()
        let pts = curve.sample(10)
        #expect(pts.count == 20) // 10 points * 2 dims
    }

    @Test("evalAll evaluates many knots")
    func evalAll() throws {
        let curve = try quadrant()
        let result = try curve.evalAll([0, 0.5, 1])
        #expect(result.count == 6)
    }
}

@Suite("Transformations")
struct TransformationTests {
    func curve() throws -> BSpline {
        try BSpline(controlPoints: [0, 0, 1, 2, 2, -1, 3, 1, 4, 0], dimension: 2)
    }

    @Test("Derivative lowers degree by one")
    func derivative() throws {
        let c = try curve()
        let d = try c.derivative()
        #expect(d.degree == c.degree - 1)
    }

    @Test("Degree elevation raises degree")
    func elevate() throws {
        let c = try curve()
        let e = try c.elevatingDegree(by: 1)
        #expect(e.degree == c.degree + 1)
    }

    @Test("toBeziers preserves dimension")
    func beziers() throws {
        let c = try curve()
        let b = try c.toBeziers()
        #expect(b.dimension == 2)
    }

    @Test("Inserting a knot adds a control point")
    func insertKnot() throws {
        let c = try curve()
        let r = try c.insertingKnot(0.5, multiplicity: 1)
        #expect(r.count == c.count + 1)
    }

    @Test("Value semantics: mutation does not alias")
    func valueSemantics() throws {
        var a = try curve()
        let b = a
        try a.setControlPoints(Array(repeating: 0, count: a.controlPoints.count))
        #expect(b.controlPoints != a.controlPoints)
    }
}

@Suite("Serialization")
struct SerializationTests {
    @Test("Round-trip through JSON")
    func roundTrip() throws {
        let curve = try BSpline(controlPoints: [0, 0, 1, 1, 2, 0, 3, 1], dimension: 2)
        let json = try curve.toJSON()
        #expect(!json.isEmpty)
        let restored = try BSpline(json: json)
        #expect(restored.count == curve.count)
        #expect(restored.controlPoints == curve.controlPoints)
    }

    @Test("Bad JSON throws instead of crashing")
    func badJSON() {
        #expect(throws: TinySplineError.self) {
            _ = try BSpline(json: "{ not valid json ")
        }
    }
}

@Suite("Arc length & framing")
struct AdvancedTests {
    func curve() throws -> BSpline {
        try BSpline(controlPoints: [0, 0, 0, 1, 1, 0, 2, 1, 0, 3, 0, 0], dimension: 3)
    }

    @Test("Chord lengths expose total arc length")
    func chordLengths() throws {
        let c = try curve()
        let cl = try c.chordLengths(numSamples: 100)
        #expect(cl.arcLength > 0)
        let knot = try cl.knot(forT: 0.5)
        #expect(c.domain.contains(knot))
    }

    @Test("RMF produces one frame per knot")
    func rmf() throws {
        let c = try curve()
        let frames = try c.computeRMF(at: [0, 0.25, 0.5, 0.75, 1.0])
        #expect(frames.count == 5)
        // Tangent/normal/binormal should be ~unit length.
        for f in frames {
            #expect(Swift.abs(simd_length(f.tangent) - 1) < 1e-6)
        }
    }
}

@Suite("Morphing")
struct MorphTests {
    @Test("Morph endpoints reproduce origin and target")
    func endpoints() throws {
        let a = try BSpline(controlPoints: [0, 0, 1, 1, 2, 0, 3, 1], dimension: 2)
        let b = try BSpline(controlPoints: [0, 1, 1, 0, 2, 1, 3, 0], dimension: 2)
        let morph = try a.morph(to: b)
        let at0 = try morph(0).eval(0.5).point2
        let originAt = try a.eval(0.5).point2
        #expect(Swift.abs(at0.x - originAt.x) < 1e-6)
        #expect(Swift.abs(at0.y - originAt.y) < 1e-6)
    }
}

@Suite("Interpolation")
struct InterpolationTests {
    @Test("Cubic natural interpolation passes through points")
    func cubicNatural() throws {
        let pts: [Double] = [0, 0, 1, 2, 2, 0, 3, 2, 4, 0]
        let curve = try BSpline.interpolatingCubicNatural(points: pts, dimension: 2)
        let start = try curve.eval(curve.domain.min).point2
        #expect(Swift.abs(start.x - 0) < 1e-6)
        #expect(Swift.abs(start.y - 0) < 1e-6)
    }

    @Test("Catmull-Rom interpolation builds a valid curve")
    func catmullRom() throws {
        let pts: [Double] = [0, 0, 1, 2, 2, 0, 3, 2]
        let curve = try BSpline.interpolatingCatmullRom(points: pts, dimension: 2)
        #expect(curve.dimension == 2)
        #expect(curve.count > 0)
    }
}
