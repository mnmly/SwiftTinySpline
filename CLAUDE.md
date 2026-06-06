# SwiftTinySpline

Modern Swift bindings for [TinySpline](https://github.com/msteinbeck/tinyspline)
(B-splines / NURBS), built on Swift C++ interop.

## Architecture

- **`Sources/CTinySpline/`** — vendored TinySpline C/C++ sources (do **not** hand-edit;
  re-sync with `Scripts/update-tinyspline.sh`). Pinned version in
  `Sources/CTinySpline/UPSTREAM.txt`. Sources are vendored (committed), **not** a
  git submodule — SwiftPM clones dependencies without submodules, so a submodule
  would be empty at a consumer's build time.
  - `include/tinyspline_swift_shim.h` and `include/module.modulemap` are
    **package-maintained** (the update script preserves them). The shim wraps
    every fallible C++ call in `try/catch` so C++ exceptions never reach Swift
    (which would terminate the process) — they surface as `TinySplineError`.
- **`Sources/TinySpline/`** — the idiomatic Swift wrapper. `.interoperabilityMode(.Cxx)`.

When adding a new TinySpline operation: add a `try/catch` shim in
`tinyspline_swift_shim.h` (never call a throwing C++ method directly from Swift),
then wrap it via `Interop.checked { ... }` in the Swift layer.

## Verification

```bash
swift build && swift test     # 23 tests; must stay green
```

## Documentation

`TinySpline` ships DocC-generated reference docs (see
`Sources/TinySpline/Documentation.docc/` and `Scripts/build_docs.sh`).
**`///` doc comments on public symbols are published** to the static site at
https://mnmly.github.io/SwiftTinySpline/ and (if `EMIT_LLMS_TXT=1` is used) into
`docs/llms.txt`.

When you add or modify a `public` declaration:

- Write a `///` doc comment. One-sentence summary, then a paragraph if the *why*
  is non-obvious. Skip restating what the signature already says.
- Document each parameter with `- Parameter name:` / a `- Parameters:` block.
  Use the **internal** name when there's an external label — DocC warns otherwise.
  And document **all** parameters once you document one, or none.
- Cross-reference related symbols with double-backtick links, e.g.
  `` ``BSpline/eval(_:)`` ``. DocC link syntax is signature-sensitive:
  `foo(_:)` and `foo(_:_:)` are different. Don't put links in the one-line summary.
- When you add a new top-level symbol that belongs in the curated sidebar, add it
  under the appropriate `## Topics` group in
  `Sources/TinySpline/Documentation.docc/TinySpline.md`. Topics are organized by
  *user task*, not alphabetic order.

Verify before declaring documentation work done:

```bash
REPO_URL=https://github.com/mnmly/SwiftTinySpline ./Scripts/build_docs.sh
```

Expect exit 0 and no new "doesn't exist at" or "missing documentation" warnings
attributable to your changes.
