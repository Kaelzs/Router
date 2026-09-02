@testable import Router
import Dispatch
import Foundation
import Testing

@Suite("RouterReadWriteLock")
struct RouterReadWriteLockTests {
    private let blockedTimeout = DispatchTimeInterval.milliseconds(100)
    private let completionTimeout = DispatchTimeInterval.seconds(5)

    @Test
    func simultaneousReadersOverlap() {
        let lock = RouterReadWriteLock(contentionReporter: {})
        let group = DispatchGroup()
        let firstReaderEntered = DispatchSemaphore(value: 0)
        let secondReaderEntered = DispatchSemaphore(value: 0)
        let releaseReaders = DispatchSemaphore(value: 0)

        enqueue(in: group) {
            lock.withReadAccess {
                firstReaderEntered.signal()
                releaseReaders.wait()
            }
        }

        #expect(waitForSignal(firstReaderEntered))

        enqueue(in: group) {
            lock.withReadAccess {
                secondReaderEntered.signal()
                releaseReaders.wait()
            }
        }

        defer {
            releaseReaders.signal()
            releaseReaders.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(secondReaderEntered))
    }

    @Test
    func activeWriterExcludesReadersAndOtherWriters() {
        let group = DispatchGroup()
        let firstWriterEntered = DispatchSemaphore(value: 0)
        let writerWaiting = DispatchSemaphore(value: 0)
        let secondWriterEntered = DispatchSemaphore(value: 0)
        let readerWaiting = DispatchSemaphore(value: 0)
        let readerEntered = DispatchSemaphore(value: 0)
        let releaseFirstWriter = DispatchSemaphore(value: 0)
        let releaseSecondWriter = DispatchSemaphore(value: 0)
        let waiterObservation = RouterReadWriteLock.WaiterObservation(readerDidWait: readerWaiting, writerDidWait: writerWaiting)
        let lock = RouterReadWriteLock(contentionReporter: {}, waiterObservation: waiterObservation)

        enqueue(in: group) {
            try! lock.withWriteAccess {
                firstWriterEntered.signal()
                releaseFirstWriter.wait()
            }
        }

        #expect(waitForSignal(firstWriterEntered))

        enqueue(in: group) {
            try! lock.withWriteAccess {
                secondWriterEntered.signal()
                releaseSecondWriter.wait()
            }
        }

        #expect(waitForSignal(writerWaiting))

        enqueue(in: group) {
            lock.withReadAccess {
                _ = readerEntered.signal()
            }
        }

        defer {
            releaseFirstWriter.signal()
            releaseSecondWriter.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(readerWaiting))
        #expect(isBlocked(secondWriterEntered))
        #expect(isBlocked(readerEntered))

        releaseFirstWriter.signal()
        #expect(waitForSignal(secondWriterEntered))
        #expect(isBlocked(readerEntered))

        releaseSecondWriter.signal()
        #expect(waitForSignal(readerEntered))
    }

    @Test
    func writerWaitsAndReportsOnce() {
        let reportCount = LockedInteger()
        let contentionReported = DispatchSemaphore(value: 0)
        let lock = RouterReadWriteLock {
            reportCount.increment()
            contentionReported.signal()
        }
        let group = DispatchGroup()
        let readerEntered = DispatchSemaphore(value: 0)
        let writerAttempted = DispatchSemaphore(value: 0)
        let writerEntered = DispatchSemaphore(value: 0)
        let releaseReader = DispatchSemaphore(value: 0)

        enqueue(in: group) {
            lock.withReadAccess {
                readerEntered.signal()
                releaseReader.wait()
            }
        }

        #expect(waitForSignal(readerEntered))

        enqueue(in: group) {
            writerAttempted.signal()
            try! lock.withWriteAccess {
                _ = writerEntered.signal()
            }
        }

        defer {
            releaseReader.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(writerAttempted))
        #expect(waitForSignal(contentionReported))
        #expect(isBlocked(writerEntered))
        #expect(reportCount.value == 1)

        releaseReader.signal()
        #expect(waitForSignal(writerEntered))
        #expect(reportCount.value == 1)
    }

    @Test
    func contentionReporterCanSynchronouslyReadWhileWriterWaits() {
        let lockReference = LockedValue<RouterReadWriteLock>()
        let reporterCouldRead = LockedValue<Bool>()
        let reportCount = LockedInteger()
        let reporterStarted = DispatchSemaphore(value: 0)
        let reporterReadFinished = DispatchSemaphore(value: 0)
        let readerEntered = DispatchSemaphore(value: 0)
        let writerEntered = DispatchSemaphore(value: 0)
        let releaseReader = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        let lock = RouterReadWriteLock {
            reportCount.increment()
            reporterStarted.signal()

            guard let lock = lockReference.value else {
                reporterReadFinished.signal()
                return
            }

            let canRead = lock.canCurrentThreadReadImmediately
            reporterCouldRead.value = canRead
            if canRead {
                lock.withReadAccess {}
            }
            reporterReadFinished.signal()
        }
        lockReference.value = lock

        enqueue(in: group) {
            lock.withReadAccess {
                readerEntered.signal()
                releaseReader.wait()
            }
        }

        #expect(waitForSignal(readerEntered))

        enqueue(in: group) {
            try! lock.withWriteAccess {
                _ = writerEntered.signal()
            }
        }

        #expect(waitForSignal(reporterStarted))
        let reporterReadDidFinish = waitForSignal(reporterReadFinished)
        #expect(reporterReadDidFinish)
        #expect(reporterCouldRead.value == true)
        #expect(reportCount.value == 1)

        releaseReader.signal()

        if reporterReadDidFinish {
            #expect(waitForSignal(writerEntered))
            #expect(waitForGroup(group))
        } else {
            _ = group.wait(timeout: .now() + blockedTimeout)
        }
    }

    @Test
    func nestedReaderCanFinishWhileWriterIsQueued() {
        let contentionReported = DispatchSemaphore(value: 0)
        let lock = RouterReadWriteLock {
            contentionReported.signal()
        }
        let group = DispatchGroup()
        let outerReaderEntered = DispatchSemaphore(value: 0)
        let beginNestedRead = DispatchSemaphore(value: 0)
        let nestedReaderFinished = DispatchSemaphore(value: 0)
        let writerEntered = DispatchSemaphore(value: 0)
        let releaseOuterReader = DispatchSemaphore(value: 0)

        enqueue(in: group) {
            lock.withReadAccess {
                outerReaderEntered.signal()
                beginNestedRead.wait()
                lock.withReadAccess {}
                nestedReaderFinished.signal()
                releaseOuterReader.wait()
            }
        }

        #expect(waitForSignal(outerReaderEntered))

        enqueue(in: group) {
            try! lock.withWriteAccess {
                _ = writerEntered.signal()
            }
        }

        defer {
            beginNestedRead.signal()
            releaseOuterReader.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(contentionReported))
        beginNestedRead.signal()
        #expect(waitForSignal(nestedReaderFinished))
        #expect(isBlocked(writerEntered))

        releaseOuterReader.signal()
        #expect(waitForSignal(writerEntered))
    }

    @Test
    func newReaderWaitsBehindQueuedWriter() {
        let group = DispatchGroup()
        let firstReaderEntered = DispatchSemaphore(value: 0)
        let writerWaiting = DispatchSemaphore(value: 0)
        let writerEntered = DispatchSemaphore(value: 0)
        let readerWaiting = DispatchSemaphore(value: 0)
        let secondReaderEntered = DispatchSemaphore(value: 0)
        let releaseFirstReader = DispatchSemaphore(value: 0)
        let releaseWriter = DispatchSemaphore(value: 0)
        let waiterObservation = RouterReadWriteLock.WaiterObservation(readerDidWait: readerWaiting, writerDidWait: writerWaiting)
        let lock = RouterReadWriteLock(contentionReporter: {}, waiterObservation: waiterObservation)

        enqueue(in: group) {
            lock.withReadAccess {
                firstReaderEntered.signal()
                releaseFirstReader.wait()
            }
        }

        #expect(waitForSignal(firstReaderEntered))

        enqueue(in: group) {
            try! lock.withWriteAccess {
                writerEntered.signal()
                releaseWriter.wait()
            }
        }

        #expect(waitForSignal(writerWaiting))

        enqueue(in: group) {
            lock.withReadAccess {
                _ = secondReaderEntered.signal()
            }
        }

        defer {
            releaseFirstReader.signal()
            releaseWriter.signal()
            #expect(waitForGroup(group))
        }

        #expect(waitForSignal(readerWaiting))
        #expect(isBlocked(secondReaderEntered))

        releaseFirstReader.signal()
        #expect(waitForSignal(writerEntered))
        #expect(isBlocked(secondReaderEntered))

        releaseWriter.signal()
        #expect(waitForSignal(secondReaderEntered))
    }

    @Test
    func thrownReadAndWriteBodiesRestoreLockState() {
        let lock = RouterReadWriteLock(contentionReporter: {})

        do {
            try lock.withReadAccess(throwReadBodyError)
            Issue.record("Expected the read body error to be rethrown")
        } catch {
            switch error {
            case .expected:
                break
            }
        }

        let writeGroup = DispatchGroup()
        let writeCompleted = DispatchSemaphore(value: 0)
        let writeOutcome = LockedValue<Result<Int, RouterRegistrationError>>()
        enqueue(in: writeGroup) {
            defer { writeCompleted.signal() }

            do {
                writeOutcome.value = .success(try lock.withWriteAccess { 42 })
            } catch {
                guard let registrationError = error as? RouterRegistrationError else {
                    Issue.record("Unexpected follow-up write error: \(error)")
                    return
                }
                writeOutcome.value = .failure(registrationError)
            }
        }

        let writeDidComplete = waitForSignal(writeCompleted)
        #expect(writeDidComplete)
        guard writeDidComplete else {
            return
        }
        #expect(waitForGroup(writeGroup))

        switch writeOutcome.value {
        case .success(let value):
            #expect(value == 42)
        case .failure(let error):
            Issue.record("Unexpected follow-up write error: \(error)")
        case nil:
            Issue.record("The follow-up write did not record an outcome")
        }

        let duplicateURL = URL(string: "router://duplicate")!
        let throwingWriteBody: () throws(RouterRegistrationError) -> Void = {
            () throws(RouterRegistrationError) in
            throw RouterRegistrationError.duplicateRoute(duplicateURL)
        }
        do {
            try lock.withWriteAccess(throwingWriteBody)
            Issue.record("Expected the write body error to be rethrown")
        } catch let error {
            switch error {
            case .duplicateRoute(let url):
                #expect(url == duplicateURL)
            default:
                Issue.record("Unexpected registration error: \(error)")
            }
        }

        let readGroup = DispatchGroup()
        let readCompleted = DispatchSemaphore(value: 0)
        let readValue = LockedValue<Int>()
        enqueue(in: readGroup) {
            readValue.value = lock.withReadAccess { 43 }
            readCompleted.signal()
        }

        let readDidComplete = waitForSignal(readCompleted)
        #expect(readDidComplete)
        guard readDidComplete else {
            return
        }
        #expect(waitForGroup(readGroup))
        #expect(readValue.value == 43)
    }

#if !DEBUG
    @Test
    func readToWriteUpgradeThrows() {
        let lock = RouterReadWriteLock(contentionReporter: {})
        let group = DispatchGroup()
        let completed = DispatchSemaphore(value: 0)
        let outcome = LockedValue<Result<Void, RouterRegistrationError>>()

        enqueue(in: group) {
            defer { completed.signal() }

            do {
                try lock.withReadAccess {
                    try lock.withWriteAccess {}
                }
                outcome.value = .success(())
            } catch {
                guard let registrationError = error as? RouterRegistrationError else {
                    Issue.record("Unexpected upgrade error: \(error)")
                    return
                }
                outcome.value = .failure(registrationError)
            }
        }

        let didComplete = waitForSignal(completed)
        #expect(didComplete)
        guard didComplete else {
            return
        }
        #expect(waitForGroup(group))

        switch outcome.value {
        case .failure(.reentrantRegistration):
            break
        case .failure(let error):
            Issue.record("Unexpected registration error: \(error)")
        case .success:
            Issue.record("Expected read-to-write upgrade to throw")
        case nil:
            Issue.record("The upgrade did not record an outcome")
        }
    }
#endif

    private func enqueue(in group: DispatchGroup, _ body: @escaping @Sendable () -> Void) {
        group.enter()
        Thread.detachNewThread {
            defer { group.leave() }
            body()
        }
    }

    private func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + completionTimeout) == .success
    }

    private func isBlocked(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now() + blockedTimeout) == .timedOut
    }

    private func waitForGroup(_ group: DispatchGroup) -> Bool {
        group.wait(timeout: .now() + completionTimeout) == .success
    }
}

private enum ReadBodyError: Error {
    case expected
}

private func throwReadBodyError() throws(ReadBodyError) {
    throw .expected
}

private final class LockedInteger: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.withLock { storedValue }
    }

    func increment() {
        lock.withLock {
            storedValue += 1
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value?

    var value: Value? {
        get {
            lock.withLock { storedValue }
        }
        set {
            lock.withLock {
                storedValue = newValue
            }
        }
    }
}
