#if !DEBUG
@testable import Router
import Dispatch
import Foundation
import XCTest

final class RouterBenchmarks: XCTestCase {
    private let clockMetrics = [XCTClockMetric()]

    func testRegister1_000LiteralRoutesAtDepth3() {
        measureRegistration(count: 1_000, depth: 3, parameterized: false)
    }

    func testRegister10_000LiteralRoutesAtDepth3() {
        measureRegistration(count: 10_000, depth: 3, parameterized: false)
    }

    func testRegister1_000LiteralRoutesAtDepth32() {
        measureRegistration(count: 1_000, depth: 32, parameterized: false)
    }

    func testRegister1_000ParameterizedRoutesAtDepth3() {
        measureRegistration(count: 1_000, depth: 3, parameterized: true)
    }

    func testLookupAmong1_000LiteralRoutesAtDepth3() throws {
        try measureLookup(count: 1_000, depth: 3, parameterized: false)
    }

    func testLookupAmong10_000LiteralRoutesAtDepth3() throws {
        try measureLookup(count: 10_000, depth: 3, parameterized: false)
    }

    func testLookupAmong1_000LiteralRoutesAtDepth32() throws {
        try measureLookup(count: 1_000, depth: 32, parameterized: false)
    }

    func testLookupAmong1_000ParameterizedRoutesAtDepth3() throws {
        try measureLookup(count: 1_000, depth: 3, parameterized: true)
    }

    func testPreOpenThroughputWith1Reader() throws {
        try measureReaderThroughput(readerCount: 1)
    }

    func testPreOpenThroughputWith4Readers() throws {
        try measureReaderThroughput(readerCount: 4)
    }


    private func measureRegistration(count: Int, depth: Int, parameterized: Bool) {
        let workload = makeBenchmarkRouteWorkload(count: count, depth: depth, parameterized: parameterized)
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        var insertedCount = 0
        var registrationError: Error?

        measure(metrics: clockMetrics, options: options) {
            let router = Router(openHandler: BenchmarkOpenHandler())
            startMeasuring()
            do {
                insertedCount = try router.register(workload.registeredURLs, destination: .urlHandler(BenchmarkDestination.self))
            } catch {
                registrationError = error
            }
            stopMeasuring()
            withExtendedLifetime(router) {}
        }

        if let registrationError {
            XCTFail("Registration failed: \(registrationError)")
        }
        XCTAssertEqual(insertedCount, count)
    }

    private func measureLookup(count: Int, depth: Int, parameterized: Bool) throws {
        let workload = makeBenchmarkRouteWorkload(count: count, depth: depth, parameterized: parameterized)
        let router = Router(openHandler: BenchmarkOpenHandler())
        _ = try router.register(workload.registeredURLs, destination: .urlHandler(BenchmarkDestination.self))
        // Static siblings are inserted at the front, so the first registered URL exercises the longest sibling scan.
        let selectedURL = try XCTUnwrap(workload.runtimeURLs.first)
        let lookupsPerIteration = 100
        var finalResolvedCount = 0

        measure(metrics: clockMetrics) {
            var resolvedCount = 0
            do {
                for _ in 0 ..< lookupsPerIteration {
                    if try router.preOpen(selectedURL, parameters: [:]) != nil {
                        resolvedCount += 1
                    }
                }
            } catch {
                XCTFail("Lookup failed: \(error)")
            }
            finalResolvedCount = resolvedCount
        }

        XCTAssertEqual(finalResolvedCount, lookupsPerIteration)
    }

    private func measureReaderThroughput(readerCount: Int) throws {
        let workload = makeBenchmarkRouteWorkload(count: 1_000, depth: 3, parameterized: false)
        let router = Router(openHandler: BenchmarkOpenHandler())
        _ = try router.register(workload.registeredURLs, destination: .urlHandler(BenchmarkDestination.self))
        let selectedURL = try XCTUnwrap(workload.runtimeURLs.last)
        let queues = (0 ..< readerCount).map {
            DispatchQueue(label: "router.benchmark.reader.\($0)")
        }
        let callsPerReader = 10_000 / readerCount
        var finalSuccessCount = 0
        var finalErrors: [String] = []

        measure(metrics: clockMetrics) {
            let group = DispatchGroup()
            let successCount = BenchmarkLockedCounter()
            let errors = BenchmarkLockedErrors()

            for queue in queues {
                group.enter()
                queue.async {
                    defer { group.leave() }
                    var localSuccessCount = 0
                    for _ in 0 ..< callsPerReader {
                        do {
                            if try router.preOpen(selectedURL, parameters: [:]) != nil {
                                localSuccessCount += 1
                            }
                        } catch {
                            errors.append(error)
                        }
                    }
                    successCount.add(localSuccessCount)
                }
            }

            XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
            finalSuccessCount = successCount.value
            finalErrors = errors.values
        }

        XCTAssertEqual(finalSuccessCount, 10_000)
        XCTAssertTrue(finalErrors.isEmpty, "\(finalErrors)")
    }
}

#endif
