@testable import Router
import Dispatch
import Foundation
import Testing

@Suite("NCArray", .serialized)
struct NCArrayTests {
    @Test
    func initializesWithZeroAndReservedCapacityThenGrows() {
        var empty = NCArray<Int>(count: 0)
        var reserved = NCArray<Int>(count: 4)

        let emptyInitialCount = empty.count
        let emptyInitialCapacity = empty.capacity
        let emptyInitiallyIsEmpty = empty.isEmpty
        let reservedInitialCount = reserved.count
        let reservedInitialCapacity = reserved.capacity

        #expect(emptyInitialCount == 0)
        #expect(emptyInitialCapacity == 0)
        #expect(emptyInitiallyIsEmpty)
        #expect(reservedInitialCount == 0)
        #expect(reservedInitialCapacity == 4)

        for value in 0 ..< 8 {
            empty.append(value)
            reserved.append(value)
        }

        let emptyFinalCount = empty.count
        let emptyFinalCapacity = empty.capacity
        let reservedFinalCount = reserved.count
        let reservedFinalCapacity = reserved.capacity
        let emptyValues = values(in: empty)
        let reservedValues = values(in: reserved)

        #expect(emptyFinalCount == 8)
        #expect(emptyFinalCapacity >= 8)
        #expect(reservedFinalCount == 8)
        #expect(reservedFinalCapacity >= 8)
        #expect(emptyValues == Array(0 ..< 8))
        #expect(reservedValues == Array(0 ..< 8))
    }

    @Test
    func insertsAtFrontMiddleAndEnd() {
        var array = NCArray<Int>(count: 0)
        array.append(1)
        array.append(3)

        array.insert(0, at: 0)
        array.insert(2, at: 2)
        array.insert(4, at: array.count)

        let insertedValues = values(in: array)
        #expect(insertedValues == [0, 1, 2, 3, 4])
    }

    @Test
    func borrowsUpdatesSearchesAndReducesElements() throws {
        var array = NCArray<Int>(count: 2)
        array.append(2)
        array.append(4)
        array.append(6)

        let borrowed = array.borrowElement(at: 1) { $0 }
        let oldValue = array.updateElement(at: 1) { value in
            let oldValue = value
            value = 5
            return oldValue
        }
        let firstIndex = array.firstIndex { $0 == 5 }
        let found = array.first(where: { $0 > 4 }, using: { $0 * 10 }, notFound: { -1 })
        let notFound = array.first(where: { $0 == 99 }, using: { $0 }, notFound: { -1 })
        let sum = array.reduce(0) { $0 + $1 }
        let finalValues = values(in: array)

        #expect(borrowed == 4)
        #expect(oldValue == 4)
        #expect(firstIndex == 1)
        #expect(found == 50)
        #expect(notFound == -1)
        #expect(sum == 13)
        #expect(finalValues == [2, 5, 6])
    }

    @Test
    func moveOnlyElementsSurviveGrowthAndInsertionAndDeinitializeOnce() {
        let recorder = DeinitRecorder()

        do {
            var array = NCArray<MoveOnlyToken>(count: 0)
            for id in 0 ..< 8 {
                array.append(MoveOnlyToken(id: id, recorder: recorder))
            }
            array.insert(MoveOnlyToken(id: 8, recorder: recorder), at: 0)
            array.insert(MoveOnlyToken(id: 9, recorder: recorder), at: 4)
            array.insert(MoveOnlyToken(id: 10, recorder: recorder), at: array.count)

            let ids = array.reduce([Int]()) { partialResult, token in
                var result = partialResult
                result.append(token.id)
                return result
            }
            #expect(ids == [8, 0, 1, 2, 9, 3, 4, 5, 6, 7, 10])
            #expect(recorder.counts.isEmpty)
        }

        #expect(recorder.counts == Dictionary(uniqueKeysWithValues: (0 ... 10).map { ($0, 1) }))
    }

    @Test(arguments: [1, 2, 4, 8])
    func frozenStorageSupportsConcurrentReads(queueCount: Int) {
        var array = NCArray<Int>(count: 0)
        for value in 0 ..< 1_024 {
            array.append(value)
        }
        let box = FrozenNCArrayBox(consume array)
        let checksum = LockedInteger()
        let group = DispatchGroup()
        let start = DispatchSemaphore(value: 0)

        for index in 0 ..< queueCount {
            group.enter()
            DispatchQueue(label: "router.ncarray.read.\(index)").async {
                defer { group.leave() }
                start.wait()
                let localChecksum = box.array.reduce(0) { $0 + $1 }
                checksum.add(localChecksum)
            }
        }
        for _ in 0 ..< queueCount {
            start.signal()
        }

        let completed = group.wait(timeout: .now() + 5) == .success
        #expect(completed)
        guard completed else {
            return
        }
        #expect(checksum.value == (0 ..< 1_024).reduce(0, +) * queueCount)
    }

    private func values(in array: borrowing NCArray<Int>) -> [Int] {
        array.reduce([Int]()) { partialResult, element in
            partialResult + [element]
        }
    }
}

private struct MoveOnlyToken: ~Copyable {
    let id: Int
    let recorder: DeinitRecorder

    deinit {
        recorder.record(id)
    }
}

private final class DeinitRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int: Int] = [:]

    var counts: [Int: Int] {
        lock.withLock { storage }
    }

    func record(_ id: Int) {
        lock.withLock {
            storage[id, default: 0] += 1
        }
    }
}

private final class FrozenNCArrayBox<Element: Sendable & ~Copyable>:
    @unchecked Sendable
{
    let array: NCArray<Element>

    init(_ array: consuming NCArray<Element>) {
        self.array = consume array
    }
}

private final class LockedInteger: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    func add(_ value: Int) {
        lock.withLock {
            storage += value
        }
    }
}
