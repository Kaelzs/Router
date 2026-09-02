@testable import Router
import Foundation
import Testing

@Suite("Router matching")
struct RouterMatchingTests {
    @Test
    func staticChildPrecedesParameterChildRegardlessOfRegistrationOrder() throws {
        let parameterFirstRouter = Router(openHandler: TestOpenHandler())
        try parameterFirstRouter.register(ParameterDestination.self)
        try parameterFirstRouter.register(StaticDestination.self)

        let staticFirstRouter = Router(openHandler: TestOpenHandler())
        try staticFirstRouter.register(StaticDestination.self)
        try staticFirstRouter.register(ParameterDestination.self)

        let parameterFirstResult = try #require(try parameterFirstRouter.preOpen("router://matching.test/users/settings", parameters: [:]))
        let staticFirstResult = try #require(try staticFirstRouter.preOpen("router://matching.test/users/settings", parameters: [:]))
        let staticDestination = Destination.urlHandler(StaticDestination.self)

        #expect(parameterFirstResult.destination.typeDescription == staticDestination.typeDescription)
        #expect(parameterFirstResult.parameters.isEmpty)
        #expect(staticFirstResult.destination.typeDescription == staticDestination.typeDescription)
        #expect(staticFirstResult.parameters.isEmpty)
    }

}

private enum ParameterDestination: DestinationURLHandler {
    static let routeURLs = [URL(string: "router://matching.test/users/:id")!]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum StaticDestination: DestinationURLHandler {
    static let routeURLs = [URL(string: "router://matching.test/users/settings")!]

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}
