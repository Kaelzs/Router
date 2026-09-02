import Dispatch
import Foundation
import os.log

final class RouterReadWriteLock: @unchecked Sendable {
    typealias ContentionReporter = @Sendable () -> Void

    struct WaiterObservation: Sendable {
        let readerDidWait: DispatchSemaphore?
        let writerDidWait: DispatchSemaphore?
    }

    private let condition = NSCondition()
    private var activeReaders = 0
    private var waitingWriters = 0
    private var writerIsActive = false
    private var readDepthByThread: [ObjectIdentifier: Int] = [:]
    private var reporterReadAllowanceByThread: [ObjectIdentifier: Int] = [:]
    private let contentionReporter: ContentionReporter
    private let waiterObservation: WaiterObservation?

    init(contentionReporter: @escaping ContentionReporter = {
        os_log("Router registration is waiting for another routing operation to finish", log: OSLog(subsystem: "Router", category: "Concurrency"), type: .error)
    }, waiterObservation: WaiterObservation? = nil) {
        self.contentionReporter = contentionReporter
        self.waiterObservation = waiterObservation
    }

    var canCurrentThreadReadImmediately: Bool {
        let thread = ObjectIdentifier(Thread.current)

        condition.lock()
        defer { condition.unlock() }
        return canBeginRead(on: thread)
    }

    func withReadAccess<Failure: Error, Result: ~Copyable>(_ body: () throws(Failure) -> Result) throws(Failure) -> Result {
        let thread = ObjectIdentifier(Thread.current)

        condition.lock()
        var didObserveWait = false
        while !canBeginRead(on: thread) {
            if !didObserveWait {
                _ = waiterObservation?.readerDidWait?.signal()
                didObserveWait = true
            }
            condition.wait()
        }
        activeReaders += 1
        readDepthByThread[thread, default: 0] += 1
        condition.unlock()

        defer {
            condition.lock()
            activeReaders -= 1

            let remainingDepth = readDepthByThread[thread, default: 1] - 1
            if remainingDepth == 0 {
                readDepthByThread.removeValue(forKey: thread)
            } else {
                readDepthByThread[thread] = remainingDepth
            }

            if activeReaders == 0 {
                condition.broadcast()
            }
            condition.unlock()
        }

        return try body()
    }

    func withWriteAccess<Result: ~Copyable>(_ body: () throws(RouterRegistrationError) -> Result) throws(RouterRegistrationError) -> Result {
        let thread = ObjectIdentifier(Thread.current)

        condition.lock()
        if readDepthByThread[thread] != nil {
            condition.unlock()
            assertionFailure("Router registration cannot begin while the current thread is routing")
            throw .reentrantRegistration
        }

        waitingWriters += 1
        let mustWait = activeReaders > 0 || writerIsActive
        if mustWait {
            reporterReadAllowanceByThread[thread, default: 0] += 1
            reportContention(on: thread)
        }

        var didObserveWait = false
        while activeReaders > 0 || writerIsActive {
            if !didObserveWait {
                _ = waiterObservation?.writerDidWait?.signal()
                didObserveWait = true
            }
            condition.wait()
        }
        waitingWriters -= 1
        writerIsActive = true
        condition.unlock()

        defer {
            condition.lock()
            writerIsActive = false
            condition.broadcast()
            condition.unlock()
        }

        return try body()
    }

    private func canBeginRead(on thread: ObjectIdentifier) -> Bool {
        guard !writerIsActive else {
            return false
        }

        return waitingWriters == 0
            || readDepthByThread[thread] != nil
            || reporterReadAllowanceByThread[thread] != nil
    }

    private func reportContention(on thread: ObjectIdentifier) {
        condition.unlock()
        defer {
            condition.lock()

            let remainingDepth =
                reporterReadAllowanceByThread[thread, default: 1] - 1
            if remainingDepth == 0 {
                reporterReadAllowanceByThread.removeValue(forKey: thread)
            } else {
                reporterReadAllowanceByThread[thread] = remainingDepth
            }
        }

        contentionReporter()
    }
}
