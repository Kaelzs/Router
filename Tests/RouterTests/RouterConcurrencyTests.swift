@testable import Router
import Dispatch
import Foundation
import Testing

@Suite("Router concurrency", .serialized)
struct RouterConcurrencyTests {
    @Test
    func simultaneousPreOpenCallsReachPrepareTogether() throws {
        let gate = BlockingPrepareGate(target: "router://concurrency.test/simultaneous", blockedCallCount: 2)
        let router = Router(openHandler: TestOpenHandler())
        try router.register(ConcurrencyBaseDestination.self)
        try router.register(GatedPrepareMiddleware(gate: gate))

        let group = DispatchGroup()
        let successfulReads = LockedCounter()
        let errors = LockedErrors()

        for _ in 0 ..< 2 {
            enqueue(in: group) {
                do {
                    let result = try router.preOpen("router://concurrency.test/simultaneous", parameters: [:])
                    if result != nil {
                        successfulReads.increment()
                    } else {
                        errors.append("The registered route did not resolve")
                    }
                } catch {
                    errors.append(error)
                }
            }
        }

        defer {
            gate.release.signal()
            gate.release.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(gate.entered))
        #expect(waitForSignal(gate.entered))

        gate.release.signal()
        gate.release.signal()
        #expect(waitForGroup(group))
        #expect(successfulReads.value == 2)
        #expect(errors.values.isEmpty)
    }

    @Test
    func registrationWaitsForPreOpenAndReportsOnce() throws {
        let gate = BlockingPrepareGate(target: "router://concurrency.test/registration-wait", blockedCallCount: 1)
        let contentionReported = DispatchSemaphore(value: 0)
        let writerDidWait = DispatchSemaphore(value: 0)
        let reportCount = LockedCounter()
        let contentionReporter: RouterReadWriteLock.ContentionReporter = {
            reportCount.increment()
            contentionReported.signal()
        }
        let router = Router(openHandler: TestOpenHandler(), contentionReporter: contentionReporter, waiterObservation: .init(readerDidWait: nil, writerDidWait: writerDidWait))
        try router.register(ConcurrencyBaseDestination.self)
        try router.register(GatedPrepareMiddleware(gate: gate))

        let group = DispatchGroup()
        let readerCompleted = DispatchSemaphore(value: 0)
        let registrationCompleted = DispatchSemaphore(value: 0)
        let errors = LockedErrors()

        enqueue(in: group) {
            defer { readerCompleted.signal() }
            do {
                _ = try router.preOpen("router://concurrency.test/registration-wait", parameters: [:])
            } catch {
                errors.append(error)
            }
        }

        #expect(waitForSignal(gate.entered))

        enqueue(in: group) {
            defer { registrationCompleted.signal() }
            do {
                try router.register(RegistrationWaitDestination.self)
            } catch {
                errors.append(error)
            }
        }

        defer {
            gate.release.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(contentionReported))
        #expect(waitForSignal(writerDidWait))
        #expect(isPending(registrationCompleted))
        #expect(reportCount.value == 1)

        gate.release.signal()
        #expect(waitForSignal(readerCompleted))
        #expect(waitForSignal(registrationCompleted))
        #expect(waitForGroup(group))
        #expect(reportCount.value == 1)
        #expect(errors.values.isEmpty)

        let registered = try router.preOpen("router://concurrency.test/registration-finished", parameters: [:])
        #expect(registered != nil)
    }

    @Test
    func middlewareRegistrationAppliesOnlyToTheNextEpoch() throws {
        let gate = BlockingPrepareGate(target: "router://concurrency.test/middleware-epoch", blockedCallCount: 1)
        let writerDidWait = DispatchSemaphore(value: 0)
        let router = Router(openHandler: TestOpenHandler(), contentionReporter: {}, waiterObservation: .init(readerDidWait: nil, writerDidWait: writerDidWait))
        try router.register(ConcurrencyBaseDestination.self)
        try router.register(GatedPrepareMiddleware(gate: gate))

        let group = DispatchGroup()
        let firstReadCompleted = DispatchSemaphore(value: 0)
        let registrationCompleted = DispatchSemaphore(value: 0)
        let firstReadSawLateMiddleware = LockedValue<Bool>()
        let errors = LockedErrors()

        enqueue(in: group) {
            defer { firstReadCompleted.signal() }
            do {
                let result = try router.preOpen("router://concurrency.test/middleware-epoch", parameters: [:])
                firstReadSawLateMiddleware.value = result?.parameters["late-middleware"] as? Bool ?? false
            } catch {
                errors.append(error)
            }
        }

        #expect(waitForSignal(gate.entered))

        enqueue(in: group) {
            defer { registrationCompleted.signal() }
            do {
                try router.register(LateMiddleware())
            } catch {
                errors.append(error)
            }
        }

        defer {
            gate.release.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(writerDidWait))
        #expect(isPending(registrationCompleted))
        gate.release.signal()
        #expect(waitForSignal(firstReadCompleted))
        #expect(waitForSignal(registrationCompleted))
        #expect(firstReadSawLateMiddleware.value == false)

        let nextReadResult = try router.preOpen("router://concurrency.test/middleware-epoch", parameters: [:])
        let nextRead = try #require(nextReadResult)
        #expect(nextRead.parameters["late-middleware"] as? Bool == true)
        #expect(errors.values.isEmpty)
    }

    @Test
    func nestedPreOpenFinishesWhileWriterIsQueued() throws {
        let controller = NestedPreOpenController()
        let writerDidWait = DispatchSemaphore(value: 0)
        let router = Router(openHandler: TestOpenHandler(), contentionReporter: {}, waiterObservation: .init(readerDidWait: nil, writerDidWait: writerDidWait))
        try router.register(ConcurrencyBaseDestination.self)
        try router.register(NestedPreOpenMiddleware(controller: controller))

        let group = DispatchGroup()
        let outerCompleted = DispatchSemaphore(value: 0)
        let registrationCompleted = DispatchSemaphore(value: 0)
        let errors = LockedErrors()

        enqueue(in: group) {
            defer { outerCompleted.signal() }
            do {
                _ = try router.preOpen("router://concurrency.test/nested-outer", parameters: [:])
            } catch {
                errors.append(error)
            }
        }

        #expect(waitForSignal(controller.outerEntered))

        enqueue(in: group) {
            defer { registrationCompleted.signal() }
            do {
                try router.register(NestedWriterDestination.self)
            } catch {
                errors.append(error)
            }
        }

        defer {
            controller.beginNested.signal()
            controller.releaseOuter.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(writerDidWait))
        controller.beginNested.signal()
        #expect(waitForSignal(controller.nestedFinished))
        #expect(controller.nestedResolved.value == true)
        #expect(isPending(registrationCompleted))

        controller.releaseOuter.signal()
        #expect(waitForSignal(outerCompleted))
        #expect(waitForSignal(registrationCompleted))
        #expect(waitForGroup(group))
        #expect(errors.values.isEmpty)
    }

    @Test
    func aNewPreOpenWaitsBehindTheQueuedRegistration() throws {
        let controller = WriterPriorityController()
        let readerDidWait = DispatchSemaphore(value: 0)
        let writerDidWait = DispatchSemaphore(value: 0)
        let router = Router(openHandler: TestOpenHandler(), contentionReporter: {}, waiterObservation: .init(readerDidWait: readerDidWait, writerDidWait: writerDidWait))
        try router.register(ConcurrencyBaseDestination.self)
        try router.register(WriterPriorityMiddleware(controller: controller))

        let group = DispatchGroup()
        let firstReadCompleted = DispatchSemaphore(value: 0)
        let registrationCompleted = DispatchSemaphore(value: 0)
        let secondReadCompleted = DispatchSemaphore(value: 0)
        let secondReadResolved = LockedValue<Bool>()
        let errors = LockedErrors()

        enqueue(in: group) {
            defer { firstReadCompleted.signal() }
            do {
                _ = try router.preOpen("router://concurrency.test/priority-active", parameters: [:])
            } catch {
                errors.append(error)
            }
        }

        #expect(waitForSignal(controller.activeReaderEntered))

        enqueue(in: group) {
            defer { registrationCompleted.signal() }
            do {
                try router.register(WriterPriorityDestination.self)
            } catch {
                errors.append(error)
            }
        }

        #expect(waitForSignal(writerDidWait))

        enqueue(in: group) {
            defer { secondReadCompleted.signal() }
            do {
                let result = try router.preOpen("router://concurrency.test/priority-new", parameters: [:])
                secondReadResolved.value = result != nil
            } catch {
                errors.append(error)
            }
        }

        defer {
            controller.releaseActiveReader.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(readerDidWait))
        #expect(isPending(controller.newReaderReachedPrepare))

        controller.releaseActiveReader.signal()
        #expect(waitForSignal(firstReadCompleted))
        #expect(waitForSignal(registrationCompleted))
        #expect(waitForSignal(controller.newReaderReachedPrepare))
        #expect(waitForSignal(secondReadCompleted))
        #expect(waitForGroup(group))
        #expect(secondReadResolved.value == true)
        #expect(errors.values.isEmpty)
    }

#if !DEBUG
    @Test
    func registrationFromPrepareThrowsReentrantRegistration() throws {
        let attempt = RegistrationAttemptRecorder()
        let router = Router(openHandler: TestOpenHandler())
        try router.register(ConcurrencyBaseDestination.self)
        try router.register(PrepareRegistrationMiddleware(attempt: attempt))

        let group = DispatchGroup()
        let completed = DispatchSemaphore(value: 0)
        let errors = LockedErrors()

        enqueue(in: group) {
            defer { completed.signal() }
            do {
                _ = try router.preOpen("router://concurrency.test/reentrant-prepare", parameters: [:])
            } catch {
                errors.append(error)
            }
        }

        let didComplete = waitForSignal(completed)
        #expect(didComplete)
        guard didComplete else {
            return
        }
        #expect(waitForGroup(group))
        expectReentrantFailure(attempt.outcome)
        #expect(errors.values.isEmpty)
    }

#endif

    private func expectReentrantFailure(_ outcome: RegistrationAttempt?) {
        switch outcome {
        case .failure(.reentrantRegistration):
            break
        case .failure(let error):
            Issue.record("Unexpected registration error: \(error)")
        case .success:
            Issue.record("Expected registration to fail while routing")
        case nil:
            Issue.record("The registration attempt did not record an outcome")
        }
    }

}

private struct GatedPrepareMiddleware: Middleware {
    let gate: BlockingPrepareGate

    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        gate.pauseIfNeeded(for: string)
        return (string, parameters)
    }
}

private final class BlockingPrepareGate: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private let target: String
    private var remainingBlockedCalls: Int

    init(target: String, blockedCallCount: Int) {
        self.target = target
        self.remainingBlockedCalls = blockedCallCount
    }

    func pauseIfNeeded(for string: String) {
        let shouldPause = lock.withLock {
            guard string == target, remainingBlockedCalls > 0 else {
                return false
            }
            remainingBlockedCalls -= 1
            return true
        }

        if shouldPause {
            entered.signal()
            release.wait()
        }
    }
}

private struct LateMiddleware: Middleware {
    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        var parameters = parameters
        parameters["late-middleware"] = true
        return (string, parameters)
    }
}

private final class NestedPreOpenController: @unchecked Sendable {
    let outerEntered = DispatchSemaphore(value: 0)
    let beginNested = DispatchSemaphore(value: 0)
    let nestedFinished = DispatchSemaphore(value: 0)
    let releaseOuter = DispatchSemaphore(value: 0)
    let nestedResolved = LockedValue<Bool>()
}

private struct NestedPreOpenMiddleware: Middleware {
    let controller: NestedPreOpenController

    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        guard string == "router://concurrency.test/nested-outer" else {
            return (string, parameters)
        }

        controller.outerEntered.signal()
        controller.beginNested.wait()
        controller.nestedResolved.value = (try? router.preOpen("router://concurrency.test/nested-inner", parameters: [:])) != nil
        controller.nestedFinished.signal()
        controller.releaseOuter.wait()
        return (string, parameters)
    }
}

private final class WriterPriorityController: @unchecked Sendable {
    let activeReaderEntered = DispatchSemaphore(value: 0)
    let releaseActiveReader = DispatchSemaphore(value: 0)
    let newReaderReachedPrepare = DispatchSemaphore(value: 0)
}

private struct WriterPriorityMiddleware: Middleware {
    let controller: WriterPriorityController

    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        switch string {
        case "router://concurrency.test/priority-active":
            controller.activeReaderEntered.signal()
            controller.releaseActiveReader.wait()
        case "router://concurrency.test/priority-new":
            controller.newReaderReachedPrepare.signal()
        default:
            break
        }
        return (string, parameters)
    }
}

private enum RegistrationAttempt {
    case success
    case failure(RouterRegistrationError)
}

private final class RegistrationAttemptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedOutcome: RegistrationAttempt?

    var outcome: RegistrationAttempt? {
        lock.withLock { storedOutcome }
    }

    func record(_ outcome: RegistrationAttempt) {
        lock.withLock {
            storedOutcome = outcome
        }
    }
}

private struct PrepareRegistrationMiddleware: Middleware {
    let attempt: RegistrationAttemptRecorder

    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        guard string == "router://concurrency.test/reentrant-prepare" else {
            return (string, parameters)
        }

        do {
            try router.register(ReentrantDestination.self)
            attempt.record(.success)
        } catch {
            attempt.record(.failure(error))
        }
        return (string, parameters)
    }
}

private enum ConcurrencyBaseDestination: DestinationURLHandler {
    static let routeURLs = [
        URL(string: "router://concurrency.test/simultaneous")!,
        URL(string: "router://concurrency.test/registration-wait")!,
        URL(string: "router://concurrency.test/middleware-epoch")!,
        URL(string: "router://concurrency.test/nested-outer")!,
        URL(string: "router://concurrency.test/nested-inner")!,
        URL(string: "router://concurrency.test/priority-active")!,
        URL(string: "router://concurrency.test/reentrant-prepare")!,
    ]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum RegistrationWaitDestination: DestinationURLHandler {
    static let routeURLs = [URL(string: "router://concurrency.test/registration-finished")!]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum NestedWriterDestination: DestinationURLHandler {
    static let routeURLs = [URL(string: "router://concurrency.test/nested-writer")!]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum WriterPriorityDestination: DestinationURLHandler {
    static let routeURLs = [URL(string: "router://concurrency.test/priority-new")!]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum ReentrantDestination: DestinationURLHandler {
    static let routeURLs = [URL(string: "router://concurrency.test/reentrant-registered")!]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}
