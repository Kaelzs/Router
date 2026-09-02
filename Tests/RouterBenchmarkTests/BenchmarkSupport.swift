#if !DEBUG
@testable import Router
import Dispatch
import Foundation

final class BenchmarkOpenHandler: RouterOpenHandler, Sendable {
    @MainActor
    func performJump(parameters: [String: Any], animated: Bool, url: URL, destination: any DestinationViewController.Type) throws {}
}

enum BenchmarkDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

struct BenchmarkRouteWorkload {
    let registeredURLs: [URL]
    let runtimeURLs: [String]
}

func makeBenchmarkRouteWorkload(count: Int, depth: Int, parameterized: Bool) -> BenchmarkRouteWorkload {
    precondition(count > 0)
    precondition(depth >= 2)

    var registeredURLs: [URL] = []
    var runtimeURLs: [String] = []
    registeredURLs.reserveCapacity(count)
    runtimeURLs.reserveCapacity(count)

    for routeIndex in 0 ..< count {
        var registeredPath = ["route-\(routeIndex)"]
        var runtimePath = registeredPath

        if depth > 2 {
            for componentIndex in 1 ..< depth - 1 {
                let component = "segment-\(componentIndex)"
                registeredPath.append(component)
                runtimePath.append(component)
            }
        }

        if parameterized {
            registeredPath.append(":value")
            runtimePath.append("value-\(routeIndex)")
        } else {
            let leaf = "leaf-\(routeIndex)"
            registeredPath.append(leaf)
            runtimePath.append(leaf)
        }

        let registeredString = "router://benchmark.test/" + registeredPath.joined(separator: "/")
        let runtimeString = "router://benchmark.test/" + runtimePath.joined(separator: "/")
        registeredURLs.append(URL(string: registeredString)!)
        runtimeURLs.append(runtimeString)
    }

    return BenchmarkRouteWorkload(registeredURLs: registeredURLs, runtimeURLs: runtimeURLs)
}

final class BenchmarkLockedCounter: @unchecked Sendable {
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

final class BenchmarkLockedErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.withLock { storage }
    }

    func append(_ error: Error) {
        append(String(describing: error))
    }

    func append(_ message: String) {
        lock.withLock {
            storage.append(message)
        }
    }
}
#endif
