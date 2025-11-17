//
//  ~Copyable + Array.swift
//  Router
//
//  Created by Kael on 2024/10/30.
//

struct NCArray<Element: ~Copyable>: ~Copyable {
    private var storage: UnsafeMutableBufferPointer<Element>
    private(set) var count: Int

    var capacity: Int { storage.count }

    init(count: Int) {
        storage = .allocate(capacity: count)
        self.count = 0
    }

    deinit {
        storage.extracting(0 ..< count).deinitialize()
        storage.deallocate()
    }
}

extension NCArray: @unchecked Sendable where Element: Sendable & ~Copyable {}

extension NCArray where Element: ~Copyable {
    var isEmpty: Bool { count == 0 }
}

extension NCArray where Element: ~Copyable {
    func borrowElement<ErrorType: Error, ResultType: ~Copyable>(at index: Int, using body: (borrowing Element) throws(ErrorType) -> ResultType) throws(ErrorType) -> ResultType {
        precondition(index >= 0 && index < count)
        return try body(storage[index])
    }

    mutating func updateElement<ErrorType: Error, ResultType: ~Copyable>(at index: Int, using body: (inout Element) throws(ErrorType) -> ResultType) throws(ErrorType) -> ResultType {
        precondition(index >= 0 && index < count)
        return try body(&storage[index])
    }
}

extension NCArray where Element: ~Copyable {
    private mutating func preAppendCheck(_ countToAppend: Int) {
        if capacity < count + countToAppend {
            let newCapacity = Swift.max(count + countToAppend, 2 * capacity)
            let newStorage = UnsafeMutableBufferPointer<Element>.allocate(capacity: newCapacity)
            let source = storage.extracting(0 ..< count)
            let i = newStorage.moveInitialize(fromContentsOf: source)
            assert(i == count)
            storage.deallocate()
            storage = newStorage
        }
    }

    mutating func append(_ item: consuming Element) {
        preAppendCheck(1)
        storage.initializeElement(at: count, to: item)
        count += 1
    }

    mutating func insert(_ item: consuming Element, at index: Int) {
        precondition(index >= 0 && index <= count)
        preAppendCheck(1)
        if index < count {
            let source = storage.extracting(index ..< count)
            let target = storage.extracting(index + 1 ..< count + 1)
            let last = target.moveInitialize(fromContentsOf: source)
            assert(last == target.endIndex)
        }
        storage.initializeElement(at: index, to: item)
        count += 1
    }
}

extension NCArray where Element: ~Copyable {
    func firstIndex(where prediction: (borrowing Element) -> Bool) -> Int? {
        for index in 0 ..< count {
            let result = borrowElement(at: index) { element in
                prediction(element)
            }

            if result {
                return index
            }
        }

        return nil
    }

    func first<ErrorType: Error, ResultType: ~Copyable>(where prediction: (borrowing Element) -> Bool, using body: (borrowing Element) throws(ErrorType) -> ResultType, notFound: () throws(ErrorType) -> ResultType) throws(ErrorType) -> ResultType {
        for index in 0 ..< count {
            let result = try borrowElement(at: index) { element throws(ErrorType) -> ResultType? in
                if prediction(element) {
                    return try body(element)
                } else {
                    return nil
                }
            }

            if let result {
                return result
            }
            continue
        }

        return try notFound()
    }
}

extension NCArray where Element: ~Copyable {
    func reduce<ErrorType: Error, ResultType: ~Copyable>(_ initial: consuming ResultType, _ nextPartialResult: (borrowing ResultType, borrowing Element) throws(ErrorType) -> ResultType) throws(ErrorType) -> ResultType {
        var result = initial

        for index in 0 ..< count {
            result = try borrowElement(at: index) { element throws(ErrorType) in
                try nextPartialResult(result, element)
            }
        }

        return result
    }
}
