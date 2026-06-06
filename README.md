# SwiftTinySpline

Modern Swift bindings for [TinySpline](https://github.com/msteinbeck/tinyspline)
(v0.6.0) — a small, dependency-free C/C++ library for B-splines and NURBS.

Built on **Swift C++ interoperability**: the wrapper talks directly to
TinySpline's C++ API, so there is no hand-maintained C shim layer to drift out
of sync. The native sources are vendored and compiled as part of the package, so
a single `swift build` works on macOS, iOS, tvOS, watchOS, and Linux — no
prebuilt binaries to manage.

## Installation

```swift
.package(url: "https://github.com/<you>/SwiftTinySpline.git", from: "0.1.0")
```

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "TinySpline", package: "SwiftTinySpline")
])
```

> **Note:** `TinySpline` enables C++ interop. Targets that depend on it must
> also enable it (`swiftSettings: [.interoperabilityMode(.Cxx)]`) — a current
> SPM constraint ([swift#66156](https://github.com/swiftlang/swift/issues/66156)).

## Usage

```swift
import TinySpline
import simd

// Cubic 2-D curve through 4 control points (x, y pairs, flattened).
let curve = try BSpline(
    controlPoints: [-1, 0, -0.5, 1, 0.5, -1, 1, 0],
    dimension: 2)

let mid: SIMD2<Double> = try curve.eval(0.5).point2   // point at u = 0.5
let path: [Double]      = curve.sample(64)            // 64 points, flattened

// Transformations return new, independent curves.
let derivative = try curve.derivative()
let elevated   = try curve.elevatingDegree(by: 1)
let beziers    = try curve.toBeziers()

// Interpolation.
let interp = try BSpline.interpolatingCatmullRom(
    points: [0, 0, 1, 2, 2, 0, 3, 2], dimension: 2)

// Arc-length reparametrization (constant-speed traversal).
let lengths = try curve.chordLengths(numSamples: 200)
let knotAtHalfway = try lengths.knot(forT: 0.5)

// Rotation-minimizing frames along a 3-D curve.
let frames = try curve3D.computeRMF(at: stride(from: 0, through: 1, by: 0.05).map { $0 })

// Morph one curve into another.
let morph = try curve.morph(to: otherCurve)
let blended = try morph(0.5)

// Serialization.
let json = try curve.toJSON()
let restored = try BSpline(json: json)
```

## Design notes

### Error handling — no process termination

TinySpline's C++ API reports failures by throwing `std::exception`. **Swift
cannot catch C++ exceptions** — an uncaught one terminates the process. To make
the binding safe, every fallible C++ call is wrapped in a `try/catch` inside a
header-only C++ shim (`tinyspline_swift_shim.h`); errors are converted to a
status and re-surfaced as a Swift `TinySplineError`. So bad input throws a normal
Swift error you can `catch` — it never crashes the host:

```swift
do {
    let s = try BSpline(json: "{ not valid")
} catch let error as TinySplineError {
    print(error.message)   // "..." instead of a crash
}
```

### Value semantics & concurrency

`BSpline`, `DeBoorNet`, `ChordLengths`, `Domain`, and `Frame` are value types
with deep-copy semantics over their underlying C++ objects, so they are
`Sendable` and cross actor/task boundaries safely:

```swift
await withTaskGroup(of: [Double].self) { group in
    for n in [16, 32, 64] { group.addTask { curve.sample(n) } }
    // ...
}
```

`Morphism` is a reference type (it reuses mutable internal buffers across
evaluations) and is intentionally **not** `Sendable`; create one per isolation
domain.

### Types

| TinySpline (C++)        | Swift                                   |
| ----------------------- | --------------------------------------- |
| `tinyspline::BSpline`   | `BSpline` (struct, value semantics)     |
| `tinyspline::DeBoorNet` | `DeBoorNet`                             |
| `tinyspline::Vec2/3/4`  | `SIMD2/3/4<Double>`                      |
| `std::vector<real>`     | `[Double]` (flattened, row-major)       |
| `tinyspline::Domain`    | `Domain`                                |
| `tinyspline::Frame`     | `Frame` (SIMD3 position/tangent/…)      |
| `tinyspline::ChordLengths` | `ChordLengths`                       |
| `tinyspline::Morphism`  | `Morphism` (class)                      |

`tsReal` is `double` (TinySpline's default precision).

## Package layout

```
Sources/
  CTinySpline/            vendored TinySpline v0.6.0 sources
    tinyspline.c, parson.c, tinysplinecxx.cxx
    UPSTREAM.txt              pinned upstream tag + commit
    include/
      tinyspline*.h
      tinyspline_swift_shim.h   exception-catching + enum/vector shims
      module.modulemap          (requires cplusplus)
  TinySpline/             idiomatic Swift wrapper
    Documentation.docc/   DocC catalog + landing page
Tests/TinySplineTests/
Scripts/
  update-tinyspline.sh    re-vendor the C/C++ sources from a pinned tag
  build_docs.sh           build the DocC static site into ./docs
```

## Native sources are vendored, not submoduled

The TinySpline C/C++ sources are **committed into the repo** rather than pulled in
as a git submodule. This is deliberate: SwiftPM clones dependencies *without*
their submodules, so a submodule'd source tree would be empty at a consumer's
build time and the package wouldn't compile. The exact upstream version is pinned
in `Sources/CTinySpline/UPSTREAM.txt`; re-sync with:

```sh
Scripts/update-tinyspline.sh v0.6.0
```

(The script preserves the package-maintained `tinyspline_swift_shim.h` and
`module.modulemap`.)

## Documentation

DocC reference docs are generated from the `///` comments:

```sh
Scripts/build_docs.sh            # static site into ./docs
Scripts/build_docs.sh preview    # live local preview
EMIT_LLMS_TXT=1 Scripts/build_docs.sh   # also emit docs/llms.txt
```

A GitHub Actions workflow (`.github/workflows/docs.yml`) builds and deploys to
GitHub Pages on push to `main`. Enable Pages first:
`gh api -X POST repos/<owner>/<repo>/pages -f build_type=workflow`.

## License

This binding is provided under the MIT license. Vendored TinySpline sources are
© 2016 Marcel Steinbeck, also MIT — see `LICENSE.tinyspline`.
