/** @file
 *  Swift-interop shim for tinyspline.
 *
 *  Two jobs:
 *
 *  1. Expose the *unscoped* nested enum `tinyspline::BSpline::Type` as a scoped
 *     enum Swift can address (its cases don't import reliably otherwise).
 *  2. Wrap every fallible C++ call in a `try/catch` so a C++ exception never
 *     reaches Swift (which would terminate the process). Errors are reported
 *     through a `Status` out-parameter and surfaced as Swift `throws`.
 *
 *  Everything here is header-only/inline — no extra translation unit to build.
 */
#pragma once

#include "tinysplinecxx.h"
#include <exception>
#include <string>
#include <vector>

namespace tinyspline_swift {

/* ----------------------------------------------------------------------- */
/* Containers & enums                                                      */
/* ----------------------------------------------------------------------- */

/**
 * Specialization of std::vector<real>. Swift C++ interop can only use
 * *specialized* class templates, so this alias makes the vector type nameable
 * and constructible from Swift.
 */
using RealVector = std::vector<tinyspline::real>;

/** Build a RealVector by copying `n` reals from `data` (may be null iff n==0). */
inline RealVector
makeRealVector(const tinyspline::real *data, size_t n)
{
	return (data && n) ? RealVector(data, data + n) : RealVector();
}

/** Mirrors `tinyspline::BSpline::Type` (kept in sync with tsBSplineType). */
enum class SplineType : int {
	Opened  = 0,
	Clamped = 1,
	Beziers = 2,
};

/* ----------------------------------------------------------------------- */
/* Error reporting                                                         */
/* ----------------------------------------------------------------------- */

/** Out-parameter carrying the outcome of a fallible shim call. */
struct Status {
	/** 0 on success; non-zero on failure. */
	int code;
	/** Human-readable message (empty on success). */
	std::string message;

	Status() : code(0), message() {}
};

namespace detail {
inline void ok(Status *s) { if (s) { s->code = 0; s->message.clear(); } }
inline void fail(Status *s, const std::exception &e)
{ if (s) { s->code = 1; s->message = e.what(); } }
inline void failUnknown(Status *s)
{ if (s) { s->code = 2; s->message = "unknown C++ exception"; } }
} // namespace detail

/* Wrap an expression returning a value; yields `fallback` on error. */
#define TS_SWIFT_TRY_VALUE(status, fallback, expr)         \
	try { auto _r = (expr); detail::ok(status); return _r; } \
	catch (const std::exception &_e) { detail::fail(status, _e); return (fallback); } \
	catch (...) { detail::failUnknown(status); return (fallback); }

/* Wrap a statement with no return value. */
#define TS_SWIFT_TRY_VOID(status, stmt)                    \
	try { stmt; detail::ok(status); }                        \
	catch (const std::exception &_e) { detail::fail(status, _e); } \
	catch (...) { detail::failUnknown(status); }

/* ----------------------------------------------------------------------- */
/* Construction                                                            */
/* ----------------------------------------------------------------------- */

inline tinyspline::BSpline
makeBSpline(size_t numControlPoints, size_t dimension,
            size_t degree, SplineType type, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		tinyspline::BSpline(
			numControlPoints, dimension, degree,
			static_cast<tinyspline::BSpline::Type>(type)));
}

inline tinyspline::BSpline
interpolateCubicNatural(const RealVector &points, size_t dimension, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		tinyspline::BSpline::interpolateCubicNatural(points, dimension));
}

inline tinyspline::BSpline
interpolateCatmullRom(const RealVector &points, size_t dimension,
                      tinyspline::real alpha,
                      bool hasFirst, const RealVector &first,
                      bool hasLast, const RealVector &last,
                      tinyspline::real epsilon, Status *s)
{
	RealVector firstCopy = first, lastCopy = last;
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		tinyspline::BSpline::interpolateCatmullRom(
			points, dimension, alpha,
			hasFirst ? &firstCopy : nullptr,
			hasLast ? &lastCopy : nullptr,
			epsilon));
}

inline tinyspline::BSpline
parseJson(const std::string &json, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		tinyspline::BSpline::parseJson(json));
}

inline tinyspline::BSpline
load(const std::string &path, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		tinyspline::BSpline::load(path));
}

/* ----------------------------------------------------------------------- */
/* Serialization                                                           */
/* ----------------------------------------------------------------------- */

inline std::string
toJson(const tinyspline::BSpline &spline, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, std::string(), spline.toJson());
}

inline void
save(const tinyspline::BSpline &spline, const std::string &path, Status *s)
{
	TS_SWIFT_TRY_VOID(s, spline.save(path));
}

/* ----------------------------------------------------------------------- */
/* Query                                                                   */
/* ----------------------------------------------------------------------- */

inline RealVector
evalAll(const tinyspline::BSpline &spline, const RealVector &knots, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, RealVector(), spline.evalAll(knots));
}

/* ----------------------------------------------------------------------- */
/* Mutation (operate on a copy, return the result)                         */
/* ----------------------------------------------------------------------- */

inline tinyspline::BSpline
setControlPoints(tinyspline::BSpline spline, const RealVector &cp, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, spline, ([&]() {
		spline.setControlPoints(cp);
		return spline;
	}()));
}

inline tinyspline::BSpline
setKnots(tinyspline::BSpline spline, const RealVector &knots, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, spline, ([&]() {
		spline.setKnots(knots);
		return spline;
	}()));
}

inline tinyspline::BSpline
setKnotAt(tinyspline::BSpline spline, size_t index,
          tinyspline::real knot, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, spline, ([&]() {
		spline.setKnotAt(index, knot);
		return spline;
	}()));
}

/* ----------------------------------------------------------------------- */
/* Transformations                                                         */
/* ----------------------------------------------------------------------- */

inline tinyspline::BSpline
insertKnot(const tinyspline::BSpline &spline, tinyspline::real u,
           size_t n, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(), spline.insertKnot(u, n));
}

inline tinyspline::BSpline
split(const tinyspline::BSpline &spline, tinyspline::real u, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(), spline.split(u));
}

inline tinyspline::BSpline
tension(const tinyspline::BSpline &spline, tinyspline::real t, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(), spline.tension(t));
}

inline tinyspline::BSpline
toBeziers(const tinyspline::BSpline &spline, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(), spline.toBeziers());
}

inline tinyspline::BSpline
derive(const tinyspline::BSpline &spline, size_t n,
       tinyspline::real epsilon, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(), spline.derive(n, epsilon));
}

inline tinyspline::BSpline
elevateDegree(const tinyspline::BSpline &spline, size_t amount,
              tinyspline::real epsilon, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		spline.elevateDegree(amount, epsilon));
}

inline tinyspline::BSpline
subSpline(const tinyspline::BSpline &spline, tinyspline::real knot0,
          tinyspline::real knot1, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(),
		spline.subSpline(knot0, knot1));
}

/* ----------------------------------------------------------------------- */
/* Spline framing (RMF)                                                    */
/* ----------------------------------------------------------------------- */

inline tinyspline::FrameSeq
computeRMF(const tinyspline::BSpline &spline, const RealVector &knots,
           bool hasFirstNormal, tinyspline::real nx,
           tinyspline::real ny, tinyspline::real nz, Status *s)
{
	tinyspline::Vec3 normal(nx, ny, nz);
	TS_SWIFT_TRY_VALUE(s, tinyspline::FrameSeq(),
		spline.computeRMF(knots, hasFirstNormal ? &normal : nullptr));
}

/* ----------------------------------------------------------------------- */
/* Reparametrization by arc length                                         */
/* ----------------------------------------------------------------------- */

inline tinyspline::ChordLengths
chordLengthsByKnots(const tinyspline::BSpline &spline,
                    const RealVector &knots, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::ChordLengths(),
		spline.chordLengths(knots));
}

inline tinyspline::ChordLengths
chordLengthsBySamples(const tinyspline::BSpline &spline,
                      size_t numSamples, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::ChordLengths(),
		spline.chordLengths(numSamples));
}

inline tinyspline::real
lengthToKnot(const tinyspline::ChordLengths &cl, tinyspline::real len, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, (tinyspline::real) 0, cl.lengthToKnot(len));
}

inline tinyspline::real
tToKnot(const tinyspline::ChordLengths &cl, tinyspline::real t, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, (tinyspline::real) 0, cl.tToKnot(t));
}

/* ----------------------------------------------------------------------- */
/* Morphing (heap-owned because tinyspline::Morphism has no default ctor)  */
/* ----------------------------------------------------------------------- */

/** Allocate a Morphism on the heap; returns nullptr on error. */
inline tinyspline::Morphism *
makeMorphism(const tinyspline::BSpline &origin,
             const tinyspline::BSpline &target,
             tinyspline::real epsilon, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, (tinyspline::Morphism *) nullptr,
		new tinyspline::Morphism(origin, target, epsilon));
}

inline void
freeMorphism(tinyspline::Morphism *m)
{ delete m; }

inline tinyspline::BSpline
morphismEval(tinyspline::Morphism *m, tinyspline::real t, Status *s)
{
	TS_SWIFT_TRY_VALUE(s, tinyspline::BSpline(), m->eval(t));
}

#undef TS_SWIFT_TRY_VALUE
#undef TS_SWIFT_TRY_VOID

} // namespace tinyspline_swift
