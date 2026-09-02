#if !DEBUG
@testable import Router
import XCTest

final class NCArrayBenchmarks: XCTestCase {
    private let clockMetrics = [XCTClockMetric()]

    func testSwiftArrayAppend10_000() {
        measure(metrics: clockMetrics) {
            var array: [Int] = []
            for value in 0 ..< 10_000 {
                array.append(value)
            }
            XCTAssertEqual(array.count, 10_000)
        }
    }

    func testNCArrayAppend10_000() {
        measure(metrics: clockMetrics) {
            var array = NCArray<Int>(count: 0)
            for value in 0 ..< 10_000 {
                array.append(value)
            }
            XCTAssertEqual(array.count, 10_000)
        }
    }

    func testSwiftArrayFrontInsert1_000() {
        measure(metrics: clockMetrics) {
            var array: [Int] = []
            for value in 0 ..< 1_000 {
                array.insert(value, at: 0)
            }
            XCTAssertEqual(array.count, 1_000)
        }
    }

    func testNCArrayFrontInsert1_000() {
        measure(metrics: clockMetrics) {
            var array = NCArray<Int>(count: 0)
            for value in 0 ..< 1_000 {
                array.insert(value, at: 0)
            }
            XCTAssertEqual(array.count, 1_000)
        }
    }

    func testSwiftArrayMiddleInsert1_000() {
        measure(metrics: clockMetrics) {
            var array: [Int] = []
            for value in 0 ..< 1_000 {
                array.insert(value, at: array.count / 2)
            }
            XCTAssertEqual(array.count, 1_000)
        }
    }

    func testNCArrayMiddleInsert1_000() {
        measure(metrics: clockMetrics) {
            var array = NCArray<Int>(count: 0)
            for value in 0 ..< 1_000 {
                array.insert(value, at: array.count / 2)
            }
            XCTAssertEqual(array.count, 1_000)
        }
    }
}
#endif
