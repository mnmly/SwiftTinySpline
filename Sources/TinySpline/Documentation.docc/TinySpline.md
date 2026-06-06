# ``TinySpline``

Modern Swift bindings for B-splines and NURBS of arbitrary degree and
dimensionality.

## Overview

`TinySpline` wraps the [TinySpline](https://github.com/msteinbeck/tinyspline)
C++ library through Swift's C++ interoperability. The central type is ``BSpline``:
a Swift **value type** (deep-copy semantics, `Sendable`) representing a curve.
You build one from control points (or by interpolating a point set), then
evaluate, sample, transform, serialize, or morph it.

Points are exchanged as flattened `[Double]` arrays in row-major order — for a
2-D curve, `[x0, y0, x1, y1, …]` — while evaluated points come back as
`SIMD2/3/4<Double>` so you get Swift's native vector math for free.

Every operation that can fail is `throws` and reports a ``TinySplineError``.
TinySpline's C++ core signals errors by throwing `std::exception`; because Swift
cannot catch C++ exceptions, those are intercepted in a C++ shim and re-surfaced
as Swift errors, so invalid input throws a catchable error instead of
terminating the process.

```swift
import TinySpline
import simd

// A clamped cubic curve through four 2-D control points.
let curve = try BSpline(
    controlPoints: [-1, 0, -0.5, 1, 0.5, -1, 1, 0],
    dimension: 2)

let mid: SIMD2<Double> = try curve.eval(0.5).point2   // point at u = 0.5
let path: [Double]      = curve.sample(64)            // 64 flattened points
let slope               = try curve.derivative()      // a new curve
```

## Topics

### Building a curve

- ``BSpline``
- ``BSpline/init(controlPoints:dimension:degree:type:)``
- ``BSpline/init(numControlPoints:dimension:degree:type:)``
- ``SplineType``

### Interpolating points

- ``BSpline/interpolatingCubicNatural(points:dimension:)``
- ``BSpline/interpolatingCatmullRom(points:dimension:alpha:first:last:epsilon:)``

### Evaluating & sampling

- ``BSpline/eval(_:)``
- ``BSpline/evalClamped(_:)``
- ``BSpline/callAsFunction(_:)``
- ``BSpline/evalAll(_:)``
- ``BSpline/sample(_:)``
- ``DeBoorNet``
- ``Domain``

### Inspecting control points & knots

- ``BSpline/controlPoints``
- ``BSpline/setControlPoints(_:)``
- ``BSpline/knots``
- ``BSpline/setKnots(_:)``
- ``BSpline/setKnot(at:to:)``
- ``BSpline/controlPoint2(at:)``
- ``BSpline/controlPoint3(at:)``

### Transforming a curve

- ``BSpline/derivative(_:epsilon:)``
- ``BSpline/elevatingDegree(by:epsilon:)``
- ``BSpline/insertingKnot(_:multiplicity:)``
- ``BSpline/split(at:)``
- ``BSpline/subSpline(from:to:)``
- ``BSpline/tensioned(_:)``
- ``BSpline/toBeziers()``

### Arc length & framing

- ``BSpline/chordLengths(numSamples:)``
- ``BSpline/chordLengths(at:)``
- ``ChordLengths``
- ``BSpline/computeRMF(at:firstNormal:)``
- ``Frame``

### Morphing between curves

- ``BSpline/morph(to:epsilon:)``
- ``Morphism``

### Serialization

- ``BSpline/toJSON()``
- ``BSpline/init(json:)``
- ``BSpline/save(to:)``
- ``BSpline/init(contentsOfFile:)``

### Errors

- ``TinySplineError``
