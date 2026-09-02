#if !DEBUG
@testable import Router
import XCTest

final class NCArrayBenchmarks: XCTestCase {
    private let clockMetrics = [XCTClockMetric()]

    func testSwiftArrayAppending10_000Elements() {
        var finalCount = 0
        measure(metrics: clockMetrics) {
            var array: [Int] = []
            for value in 0 ..< 10_000 {
                array.append(value)
            }
            finalCount = array.count
        }
        XCTAssertEqual(finalCount, 10_000)
    }

    func testNCArrayAppending10_000Elements() {
        var finalCount = 0
        measure(metrics: clockMetrics) {
            var array = NCArray<Int>(count: 0)
            for value in 0 ..< 10_000 {
                array.append(value)
            }
            finalCount = array.count
        }
        XCTAssertEqual(finalCount, 10_000)
    }

    func testSwiftArrayInserting1_000ElementsAtFront() {
        var finalCount = 0
        measure(metrics: clockMetrics) {
            var array: [Int] = []
            for value in 0 ..< 1_000 {
                array.insert(value, at: 0)
            }
            finalCount = array.count
        }
        XCTAssertEqual(finalCount, 1_000)
    }

    func testNCArrayInserting1_000ElementsAtFront() {
        var finalCount = 0
        measure(metrics: clockMetrics) {
            var array = NCArray<Int>(count: 0)
            for value in 0 ..< 1_000 {
                array.insert(value, at: 0)
            }
            finalCount = array.count
        }
        XCTAssertEqual(finalCount, 1_000)
    }

}
#endif
