import Testing
@testable import TinySpline

/// `BSpline`, `DeBoorNet`, `ChordLengths`, `Domain`, and `Frame` are value types
/// with deep-copy semantics, so they are `Sendable` and can cross actor and
/// task boundaries safely. These tests exercise that.
@Suite("Concurrency")
struct ConcurrencyTests {
    actor Sink {
        var samples: [Double] = []
        func store(_ s: [Double]) { samples = s }
    }

    @Test("BSpline can be sent into an actor")
    func sendIntoActor() async throws {
        let curve = try BSpline(controlPoints: [0, 0, 1, 1, 2, 0, 3, 1], dimension: 2)
        let sink = Sink()
        await sink.store(curve.sample(8))
        let count = await sink.samples.count
        #expect(count == 16)
    }

    @Test("Parallel sampling over a task group")
    func parallelSampling() async throws {
        let curve = try BSpline(controlPoints: [0, 0, 1, 1, 2, 0, 3, 1], dimension: 2)
        let totals = await withTaskGroup(of: Int.self) { group in
            for n in [4, 8, 16, 32] {
                group.addTask { curve.sample(n).count }
            }
            var sum = 0
            for await c in group { sum += c }
            return sum
        }
        #expect(totals == (4 + 8 + 16 + 32) * 2)
    }
}
