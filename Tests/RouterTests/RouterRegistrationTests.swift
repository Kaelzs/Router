@testable import Router
import Foundation
import Testing

@Suite("Router registration")
struct RouterRegistrationTests {
    @Test
    func publicDestinationRegistrationIncludesEveryDeclaredRoute() throws {
        let router = Router(openHandler: TestOpenHandler())

        try router.register(MultiRouteDestination.self)

        let first = try #require(try router.preOpen("router://registration.example/first", parameters: [:]))
        let second = try #require(try router.preOpen("router://registration.example/second/value", parameters: [:]))

        #expect(first.destination.typeDescription == MultiRouteDestination.destination.typeDescription)
        #expect(second.destination.typeDescription == MultiRouteDestination.destination.typeDescription)
        #expect(second.parameters["id"] as? String == "value")
    }

    @Test
    func internalBatchRegistrationReturnsInsertedRouteCount() throws {
        let router = Router(openHandler: TestOpenHandler())
        let urls = [
            url("router://batch.example/one"),
            url("router://batch.example/two"),
            url("router://batch.example/three"),
        ]

        let insertedCount: Int = try router.register(urls, destination: CountingDestination.destination)

        #expect(insertedCount == urls.count)
        for registeredURL in urls {
            let result = try router.preOpen(registeredURL.absoluteString, parameters: [:])
            #expect(result?.destination.typeDescription == CountingDestination.destination.typeDescription)
        }
    }

    @Test
    func middlewareRegistrationAcceptsAValidMiddleware() throws {
        let router = Router(openHandler: TestOpenHandler())

        try router.register(RegistrationMiddleware())
        try router.register([url("router://middleware.example/target")], destination: CountingDestination.destination)

        let result = try router.preOpen("router://middleware.example/source", parameters: [:])

        #expect(result?.url.absoluteString == "router://middleware.example/target")
        #expect(result?.destination.typeDescription == CountingDestination.destination.typeDescription)
    }

    @Test
    func normalizedRouteComponentsExposeDeclarationConflicts() throws {
        let uppercaseAndRepeatedSlash = url("RoUtEr://REGISTRATION.EXAMPLE//path/")
        let canonical = url("router://registration.example/path")
        let encoded = url("router://registration.example/%70ath")

        let firstComponents = try RouterURLParser.parseRoute(uppercaseAndRepeatedSlash).routeComponents
        let canonicalComponents = try RouterURLParser.parseRoute(canonical).routeComponents
        let encodedComponents = try RouterURLParser.parseRoute(encoded).routeComponents

        #expect(firstComponents == canonicalComponents)
        #expect(encodedComponents == canonicalComponents)

        var root = RouterTreeNode(pathComponent: "")
        root.append(parts: firstComponents, destination: CountingDestination.destination)

        let containsCanonical = root.containsDestination(for: canonicalComponents, at: 0)
        let containsEncoded = root.containsDestination(for: encodedComponents, at: 0)
        #expect(containsCanonical)
        #expect(containsEncoded)
    }

#if !DEBUG
    @Test(
        "Invalid route declarations return the exact input URL",
        arguments: [
            "router:path",
            "router://registration.example:8080/path",
            "router://registration.example/path?query=value",
            "router://registration.example/path#fragment",
        ]
    )
    func invalidDeclarationReturnsTypedError(input: String) throws {
        let router = Router(openHandler: TestOpenHandler())
        let invalidURL = url(input)

        do {
            _ = try router.register([invalidURL], destination: CountingDestination.destination)
            Issue.record("Expected \(input) to be rejected")
        } catch let error {
            guard case .invalidRouteURL(let rejectedURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(rejectedURL == invalidURL)
        }
    }

    @Test
    func duplicateAgainstExistingTreeReturnsConflictingInputAndDoesNotPartiallyInsert() throws {
        let router = Router(openHandler: TestOpenHandler())
        let batchURLs = ExistingConflictBatchDestination.routeURLs
        let firstNew = batchURLs[0]
        let existing = batchURLs[1]
        let secondNew = batchURLs[2]
        _ = try router.register([existing], destination: ExistingDestination.destination)

        do {
            try router.register(ExistingConflictBatchDestination.self)
            Issue.record("Expected the existing route to reject the whole batch")
        } catch let error {
            guard case .duplicateRoute(let conflictingURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(conflictingURL == existing)
        }

        let existingResult = try #require(try router.preOpen(existing.absoluteString, parameters: [:]))
        #expect(existingResult.destination.typeDescription == ExistingDestination.destination.typeDescription)
        try expectRouteCanBeInsertedAndResolved(firstNew, in: router)
        try expectRouteCanBeInsertedAndResolved(secondNew, in: router)
    }

    @Test
    func differentlyEncodedDuplicateWithinBatchRejectsSecondURLAtomically() throws {
        let router = Router(openHandler: TestOpenHandler())
        let batchURLs = EncodedDuplicateBatchDestination.routeURLs
        let uniqueBefore = batchURLs[0]
        let firstIdentity = batchURLs[1]
        let conflictingInput = batchURLs[2]
        let uniqueAfter = batchURLs[3]

        do {
            try router.register(EncodedDuplicateBatchDestination.self)
            Issue.record("Expected the normalized duplicate to reject the whole batch")
        } catch let error {
            guard case .duplicateRoute(let conflictingURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(conflictingURL == conflictingInput)
        }

        try expectRouteCanBeInsertedAndResolved(uniqueBefore, in: router)
        try expectRouteCanBeInsertedAndResolved(firstIdentity, resolving: conflictingInput, in: router)
        try expectRouteCanBeInsertedAndResolved(uniqueAfter, in: router)
    }

    @Test
    func invalidMemberRejectsWholeBatchBeforeMutation() throws {
        let router = Router(openHandler: TestOpenHandler())
        let batchURLs = InvalidBatchDestination.routeURLs
        let uniqueBefore = batchURLs[0]
        let invalid = batchURLs[1]
        let uniqueAfter = batchURLs[2]

        do {
            try router.register(InvalidBatchDestination.self)
            Issue.record("Expected the invalid declaration to reject the whole batch")
        } catch let error {
            guard case .invalidRouteURL(let rejectedURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(rejectedURL == invalid)
        }

        try expectRouteCanBeInsertedAndResolved(uniqueBefore, in: router)
        try expectRouteCanBeInsertedAndResolved(uniqueAfter, in: router)
    }
#endif
}

private func url(_ string: String) -> URL {
    guard let url = URL(string: string) else {
        fatalError("Invalid test URL: \(string)")
    }
    return url
}

#if !DEBUG
private func expectRouteCanBeInsertedAndResolved(_ url: URL, resolving lookupURL: URL? = nil, in router: Router) throws {
    let destination = ReplacementDestination.destination
    let insertedCount = try router.register([url], destination: destination)
    let result = try #require(try router.preOpen((lookupURL ?? url).absoluteString, parameters: [:]))

    #expect(insertedCount == 1)
    #expect(result.destination.typeDescription == destination.typeDescription)
}
#endif

private struct RegistrationMiddleware: Middleware {
    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        ("router://middleware.example/target", parameters)
    }
}

private enum MultiRouteDestination: DestinationURLHandler {
    static let routeURLs = [
        url("router://registration.example/first"),
        url("router://registration.example/second/:id"),
    ]
    static var destination: Destination { .urlHandler(Self.self) }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum CountingDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []
    static var destination: Destination { .urlHandler(Self.self) }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

#if !DEBUG
private enum ExistingDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []
    static var destination: Destination { .urlHandler(Self.self) }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum ExistingConflictBatchDestination: DestinationURLHandler {
    static var routeURLs: [URL] {
        [
            url("router://atomic.example/first-new"),
            url("router://atomic.example/existing"),
            url("router://atomic.example/second-new"),
        ]
    }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum EncodedDuplicateBatchDestination: DestinationURLHandler {
    static var routeURLs: [URL] {
        [
            url("router://encoded.example/unique-before"),
            url("router://encoded.example/%70ath"),
            url("router://encoded.example/path"),
            url("router://encoded.example/unique-after"),
        ]
    }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum InvalidBatchDestination: DestinationURLHandler {
    static var routeURLs: [URL] {
        [
            url("router://invalid-batch.example/unique-before"),
            url("router://invalid-batch.example/path?unsupported=true"),
            url("router://invalid-batch.example/unique-after"),
        ]
    }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum ReplacementDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []
    static var destination: Destination { .urlHandler(Self.self) }

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}
#endif
