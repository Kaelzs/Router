#if !DEBUG
@testable import Router
import Dispatch
import Foundation
import XCTest

final class RouterBenchmarks: XCTestCase {
    private let clockMetrics = [XCTClockMetric()]

    func testRegister10Depth3Literal() {
        measureRegistration(count: 10, depth: 3, parameterized: false)
    }

    func testRegister100Depth3Literal() {
        measureRegistration(count: 100, depth: 3, parameterized: false)
    }

    func testRegister1_000Depth3Literal() {
        measureRegistration(count: 1_000, depth: 3, parameterized: false)
    }

    func testRegister10_000Depth3Literal() {
        measureRegistration(count: 10_000, depth: 3, parameterized: false)
    }

    func testRegister10Depth32Literal() {
        measureRegistration(count: 10, depth: 32, parameterized: false)
    }

    func testRegister100Depth32Literal() {
        measureRegistration(count: 100, depth: 32, parameterized: false)
    }

    func testRegister1_000Depth32Literal() {
        measureRegistration(count: 1_000, depth: 32, parameterized: false)
    }

    func testRegister10_000Depth32Literal() {
        measureRegistration(count: 10_000, depth: 32, parameterized: false)
    }

    func testRegister10Depth3Parameterized() {
        measureRegistration(count: 10, depth: 3, parameterized: true)
    }

    func testRegister100Depth3Parameterized() {
        measureRegistration(count: 100, depth: 3, parameterized: true)
    }

    func testRegister1_000Depth3Parameterized() {
        measureRegistration(count: 1_000, depth: 3, parameterized: true)
    }

    func testRegister10_000Depth3Parameterized() {
        measureRegistration(count: 10_000, depth: 3, parameterized: true)
    }

    func testRegister10Depth32Parameterized() {
        measureRegistration(count: 10, depth: 32, parameterized: true)
    }

    func testRegister100Depth32Parameterized() {
        measureRegistration(count: 100, depth: 32, parameterized: true)
    }

    func testRegister1_000Depth32Parameterized() {
        measureRegistration(count: 1_000, depth: 32, parameterized: true)
    }

    func testRegister10_000Depth32Parameterized() {
        measureRegistration(count: 10_000, depth: 32, parameterized: true)
    }

    func testLookup10Depth3Literal() throws {
        try measureLookup(count: 10, depth: 3, parameterized: false)
    }

    func testLookup100Depth3Literal() throws {
        try measureLookup(count: 100, depth: 3, parameterized: false)
    }

    func testLookup1_000Depth3Literal() throws {
        try measureLookup(count: 1_000, depth: 3, parameterized: false)
    }

    func testLookup10_000Depth3Literal() throws {
        try measureLookup(count: 10_000, depth: 3, parameterized: false)
    }

    func testLookup10Depth32Literal() throws {
        try measureLookup(count: 10, depth: 32, parameterized: false)
    }

    func testLookup100Depth32Literal() throws {
        try measureLookup(count: 100, depth: 32, parameterized: false)
    }

    func testLookup1_000Depth32Literal() throws {
        try measureLookup(count: 1_000, depth: 32, parameterized: false)
    }

    func testLookup10_000Depth32Literal() throws {
        try measureLookup(count: 10_000, depth: 32, parameterized: false)
    }

    func testLookup10Depth3Parameterized() throws {
        try measureLookup(count: 10, depth: 3, parameterized: true)
    }

    func testLookup100Depth3Parameterized() throws {
        try measureLookup(count: 100, depth: 3, parameterized: true)
    }

    func testLookup1_000Depth3Parameterized() throws {
        try measureLookup(count: 1_000, depth: 3, parameterized: true)
    }

    func testLookup10_000Depth3Parameterized() throws {
        try measureLookup(count: 10_000, depth: 3, parameterized: true)
    }

    func testLookup10Depth32Parameterized() throws {
        try measureLookup(count: 10, depth: 32, parameterized: true)
    }

    func testLookup100Depth32Parameterized() throws {
        try measureLookup(count: 100, depth: 32, parameterized: true)
    }

    func testLookup1_000Depth32Parameterized() throws {
        try measureLookup(count: 1_000, depth: 32, parameterized: true)
    }

    func testLookup10_000Depth32Parameterized() throws {
        try measureLookup(count: 10_000, depth: 32, parameterized: true)
    }

    func testPreOpenThroughput1Reader() throws {
        try measureReaderThroughput(readerCount: 1)
    }

    func testPreOpenThroughput2Readers() throws {
        try measureReaderThroughput(readerCount: 2)
    }

    func testPreOpenThroughput4Readers() throws {
        try measureReaderThroughput(readerCount: 4)
    }

    func testPreOpenThroughput8Readers() throws {
        try measureReaderThroughput(readerCount: 8)
    }

    func testRegistrationWaitOverhead() throws {
        let readerURL = try XCTUnwrap(URL(string: "router://benchmark.test/writer-wait/reader"))
        let newURL = try XCTUnwrap(URL(string: "router://benchmark.test/writer-wait/new"))

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let gate = BenchmarkOneShotGate()
            let reportCount = BenchmarkLockedCounter()
            let errors = BenchmarkLockedErrors()
            let readerGroup = DispatchGroup()
            let contentionReporter: RouterReadWriteLock.ContentionReporter = {
                reportCount.increment()
                gate.releaseReader.signal()
            }
            let router = Router(openHandler: BenchmarkOpenHandler(), contentionReporter: contentionReporter)

            do {
                try router.register(BenchmarkBlockingMiddleware(gate: gate))
                _ = try router.register([readerURL], destination: .urlHandler(BenchmarkDestination.self))
            } catch {
                XCTFail("Benchmark setup failed: \(error)")
                startMeasuring()
                stopMeasuring()
                return
            }

            readerGroup.enter()
            DispatchQueue(label: "router.benchmark.writer-reader").async {
                defer { readerGroup.leave() }
                do {
                    let result = try router.preOpen(readerURL.absoluteString, parameters: [:])
                    if result == nil {
                        errors.append("The blocking reader route did not resolve")
                    }
                } catch {
                    errors.append(error)
                }
            }

            let readerEntered = gate.readerEntered.wait(timeout: .now() + 5) == .success
            guard readerEntered else {
                XCTFail("The benchmark reader did not enter prepare")
                startMeasuring()
                stopMeasuring()
                gate.releaseReader.signal()
                XCTAssertEqual(readerGroup.wait(timeout: .now() + 5), .success)
                return
            }

            let writerReady = DispatchSemaphore(value: 0)
            let writerMayStart = DispatchSemaphore(value: 0)
            let writerCompleted = DispatchSemaphore(value: 0)
            let insertedCount = BenchmarkLockedCounter()
            Thread.detachNewThread {
                writerReady.signal()
                writerMayStart.wait()
                defer { writerCompleted.signal() }

                do {
                    let inserted = try router.register([newURL], destination: .urlHandler(BenchmarkDestination.self))
                    if inserted == 1 {
                        insertedCount.increment()
                    } else {
                        errors.append("Registration inserted \(inserted) routes")
                    }
                } catch {
                    errors.append(error)
                }
            }

            let writerIsReady = writerReady.wait(timeout: .now() + 5) == .success
            guard writerIsReady else {
                XCTFail("The benchmark writer did not become ready")
                startMeasuring()
                stopMeasuring()
                writerMayStart.signal()
                gate.releaseReader.signal()
                _ = writerCompleted.wait(timeout: .now() + 5)
                XCTAssertEqual(readerGroup.wait(timeout: .now() + 5), .success)
                return
            }

            startMeasuring()
            writerMayStart.signal()
            let writerCompletedWithinMeasurement = writerCompleted.wait(timeout: .now() + 5) == .success
            stopMeasuring()

            var writerDidFinish = writerCompletedWithinMeasurement
            if !writerDidFinish {
                gate.releaseReader.signal()
                writerDidFinish = writerCompleted.wait(timeout: .now() + 5) == .success
                XCTAssertTrue(writerDidFinish, "The benchmark writer did not finish after cleanup")
            }
            gate.releaseReader.signal()
            XCTAssertTrue(writerCompletedWithinMeasurement, "Registration did not complete within the measured deadline")
            let readerDidFinish = readerGroup.wait(timeout: .now() + 5) == .success
            XCTAssertTrue(readerDidFinish, "The benchmark reader did not finish after cleanup")
            guard writerDidFinish, readerDidFinish else {
                return
            }
            XCTAssertEqual(reportCount.value, 1)
            XCTAssertEqual(insertedCount.value, 1)
            XCTAssertTrue(errors.values.isEmpty, "\(errors.values)")

            do {
                let result = try router.preOpen(newURL.absoluteString, parameters: [:])
                XCTAssertNotNil(result)
            } catch {
                XCTFail("Registered route lookup failed: \(error)")
            }
        }
    }

    private func measureRegistration(count: Int, depth: Int, parameterized: Bool) {
        let workload = makeBenchmarkRouteWorkload(count: count, depth: depth, parameterized: parameterized)
        var insertedCount = 0

        measure(metrics: clockMetrics) {
            let router = Router(openHandler: BenchmarkOpenHandler())
            do {
                insertedCount = try router.register(workload.registeredURLs, destination: .urlHandler(BenchmarkDestination.self))
            } catch {
                XCTFail("Registration failed: \(error)")
            }
        }

        XCTAssertEqual(insertedCount, count)
    }

    private func measureLookup(count: Int, depth: Int, parameterized: Bool) throws {
        let workload = makeBenchmarkRouteWorkload(count: count, depth: depth, parameterized: parameterized)
        let router = Router(openHandler: BenchmarkOpenHandler())
        _ = try router.register(workload.registeredURLs, destination: .urlHandler(BenchmarkDestination.self))
        let selectedURL = try XCTUnwrap(workload.runtimeURLs.first)
        var didResolve = false

        measure(metrics: clockMetrics) {
            do {
                didResolve = try router.preOpen(selectedURL, parameters: [:]) != nil
            } catch {
                XCTFail("Lookup failed: \(error)")
            }
        }

        XCTAssertTrue(didResolve)
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
                    for _ in 0 ..< callsPerReader {
                        do {
                            if try router.preOpen(selectedURL, parameters: [:]) != nil {
                                successCount.increment()
                            }
                        } catch {
                            errors.append(error)
                        }
                    }
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

private final class BenchmarkOneShotGate: @unchecked Sendable {
    let readerEntered = DispatchSemaphore(value: 0)
    let releaseReader = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private var hasBlocked = false

    func shouldBlock() -> Bool {
        lock.withLock {
            guard !hasBlocked else {
                return false
            }
            hasBlocked = true
            return true
        }
    }
}

private struct BenchmarkBlockingMiddleware: Middleware {
    let gate: BenchmarkOneShotGate

    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        guard gate.shouldBlock() else {
            return (string, parameters)
        }

        gate.readerEntered.signal()
        gate.releaseReader.wait()
        return (string, parameters)
    }
}
#endif
