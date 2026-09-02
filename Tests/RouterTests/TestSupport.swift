@testable import Router
import Dispatch
import Foundation

final class TestOpenHandler: RouterOpenHandler, Sendable {
    @MainActor
    func performJump(parameters: [String: Any], animated: Bool, url: URL, destination: any DestinationViewController.Type) throws {}
}

let testCompletionTimeout = DispatchTimeInterval.seconds(5)

func enqueue(in group: DispatchGroup, _ body: @escaping @Sendable () -> Void) {
    group.enter()
    Thread.detachNewThread {
        defer { group.leave() }
        body()
    }
}

func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
    semaphore.wait(timeout: .now() + testCompletionTimeout) == .success
}

func isPending(_ semaphore: DispatchSemaphore) -> Bool {
    semaphore.wait(timeout: .now()) == .timedOut
}

func waitForGroup(_ group: DispatchGroup) -> Bool {
    group.wait(timeout: .now() + testCompletionTimeout) == .success
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.withLock { storedValue }
    }

    func increment() {
        add(1)
    }

    func add(_ value: Int) {
        lock.withLock {
            storedValue += value
        }
    }
}

final class LockedErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.withLock { storedValues }
    }

    func append(_ error: Error) {
        append(String(describing: error))
    }

    func append(_ message: String) {
        lock.withLock {
            storedValues.append(message)
        }
    }
}

final class LockedValue<Value: Sendable>: @unchecked Sendable {
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
