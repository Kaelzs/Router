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

#if !DEBUG
    @Test
    func duplicateAgainstExistingTreeReturnsConflictingInputAndDoesNotPartiallyInsert() throws {
        let router = Router(openHandler: TestOpenHandler())
        let firstNew = url("router://atomic.example/first-new")
        let existing = url("router://atomic.example/existing")
        let secondNew = url("router://atomic.example/second-new")
        _ = try router.register([existing], destination: ExistingDestination.destination)

        do {
            _ = try router.register([firstNew, existing, secondNew], destination: CountingDestination.destination)
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
        try expectRoutesAreUnregistered([firstNew, secondNew], in: router)
    }

    @Test
    func differentlyEncodedDuplicateWithinBatchRejectsSecondURLAtomically() throws {
        let router = Router(openHandler: TestOpenHandler())
        let uniqueBefore = url("router://encoded.example/unique-before")
        let firstIdentity = url("router://encoded.example/%70ath")
        let conflictingInput = url("router://encoded.example/path")
        let uniqueAfter = url("router://encoded.example/unique-after")

        do {
            _ = try router.register([uniqueBefore, firstIdentity, conflictingInput, uniqueAfter], destination: CountingDestination.destination)
            Issue.record("Expected the normalized duplicate to reject the whole batch")
        } catch let error {
            guard case .duplicateRoute(let conflictingURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(conflictingURL == conflictingInput)
        }

        try expectRoutesAreUnregistered([uniqueBefore, firstIdentity, uniqueAfter], in: router)
    }

    @Test
    func invalidMemberRejectsWholeBatchBeforeMutation() throws {
        let router = Router(openHandler: TestOpenHandler())
        let uniqueBefore = url("router://invalid-batch.example/unique-before")
        let invalid = url("router://invalid-batch.example/path?unsupported=true")
        let uniqueAfter = url("router://invalid-batch.example/unique-after")

        do {
            _ = try router.register([uniqueBefore, invalid, uniqueAfter], destination: CountingDestination.destination)
            Issue.record("Expected the invalid declaration to reject the whole batch")
        } catch let error {
            guard case .invalidRouteURL(let rejectedURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(rejectedURL == invalid)
        }

        try expectRoutesAreUnregistered([uniqueBefore, uniqueAfter], in: router)
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
private func expectRoutesAreUnregistered(_ urls: [URL], in router: Router) throws {
    for url in urls {
        #expect(try router.preOpen(url.absoluteString, parameters: [:]) == nil)
    }
}
#endif

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

#endif
