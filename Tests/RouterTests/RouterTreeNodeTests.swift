@testable import Router
import Foundation
import Testing

@Suite("RouterTreeNode")
struct RouterTreeNodeTests {
    @Test
    func staticChildPrecedesParameterChildRegardlessOfRegistrationOrder() throws {
        let parameterDestination = Destination.urlHandler(ParameterDestination.self)
        let staticDestination = Destination.urlHandler(StaticDestination.self)

        var parameterFirstRoot = RouterTreeNode(pathComponent: "")
        parameterFirstRoot.append(parts: ["users", ":id"], at: 0, destination: parameterDestination)
        parameterFirstRoot.append(parts: ["users", "settings"], at: 0, destination: staticDestination)

        var staticFirstRoot = RouterTreeNode(pathComponent: "")
        staticFirstRoot.append(parts: ["users", "settings"], at: 0, destination: staticDestination)
        staticFirstRoot.append(parts: ["users", ":id"], at: 0, destination: parameterDestination)

        let parameterFirstMatch = parameterFirstRoot.findDestination(for: ["users", "settings"], at: 0, parameters: [:])
        let staticFirstMatch = staticFirstRoot.findDestination(for: ["users", "settings"], at: 0, parameters: [:])
        let parameterFirstResult = try #require(parameterFirstMatch)
        let staticFirstResult = try #require(staticFirstMatch)

        #expect(parameterFirstResult.destination.typeDescription == staticDestination.typeDescription)
        #expect(parameterFirstResult.parameter.isEmpty)
        #expect(staticFirstResult.destination.typeDescription == staticDestination.typeDescription)
        #expect(staticFirstResult.parameter.isEmpty)
    }

    @Test
    func staticBranchDoesNotBacktrackToParameterSiblingAfterDeeperFailure() {
        var root = RouterTreeNode(pathComponent: "")
        root.append(parts: ["users", ":id", "details"], at: 0, destination: .urlHandler(ParameterDestination.self))
        root.append(parts: ["users", "settings", "profile"], at: 0, destination: .urlHandler(StaticDestination.self))

        let result = root.findDestination(for: ["users", "settings", "details"], at: 0, parameters: [:])

        #expect(result == nil)
    }

    @Test
    func containsDestinationUsesExactDeclaredComponentsAndTerminalState() {
        var root = RouterTreeNode(pathComponent: "")
        root.append(parts: ["users", ":id"], at: 0, destination: .urlHandler(ParameterDestination.self))
        root.append(parts: ["users", "settings", "details"], at: 0, destination: .urlHandler(StaticDestination.self))

        let containsDeclaredParameter = root.containsDestination(for: ["users", ":id"], at: 0)
        let containsDeclaredStatic = root.containsDestination(for: ["users", "settings", "details"], at: 0)
        let containsIntermediateNode = root.containsDestination(for: ["users"], at: 0)
        let containsRenamedParameter = root.containsDestination(for: ["users", ":name"], at: 0)
        let treatsParameterAsWildcard = root.containsDestination(for: ["users", "123"], at: 0)
        let containsStaticIntermediateNode = root.containsDestination(for: ["users", "settings"], at: 0)
        let containsMissingStatic = root.containsDestination(for: ["users", "settings", "missing"], at: 0)

        #expect(containsDeclaredParameter)
        #expect(containsDeclaredStatic)
        #expect(!containsIntermediateNode)
        #expect(!containsRenamedParameter)
        #expect(!treatsParameterAsWildcard)
        #expect(!containsStaticIntermediateNode)
        #expect(!containsMissingStatic)
    }

    @Test
    func traversesDeepPathAndAccumulatesEveryParameter() throws {
        let routeComponents = (0 ..< 32).map { index in
            index.isMultiple(of: 2) ? "literal-\(index)" : ":parameter\(index)"
        }
        let runtimeComponents = (0 ..< 32).map { index in
            index.isMultiple(of: 2) ? "literal-\(index)" : "value-\(index)"
        }
        let destination = Destination.urlHandler(DeepDestination.self)
        var root = RouterTreeNode(pathComponent: "")

        root.append(parts: routeComponents, at: 0, destination: destination)

        let match = root.findDestination(for: runtimeComponents, at: 0, parameters: ["seed": "kept"])
        let containsRoute = root.containsDestination(for: routeComponents, at: 0)
        let result = try #require(match)
        #expect(result.destination.typeDescription == destination.typeDescription)
        #expect(result.parameter["seed"] as? String == "kept")
        #expect(containsRoute)

        for index in stride(from: 1, to: 32, by: 2) {
            #expect(result.parameter["parameter\(index)"] as? String == "value-\(index)")
        }
    }

    @Test
    func terminalIndexReturnsCurrentNodeDestinationSafely() throws {
        let destination = Destination.urlHandler(TerminalDestination.self)
        let terminalNode = RouterTreeNode(pathComponent: "terminal", destination: destination)
        let emptyNode = RouterTreeNode(pathComponent: "terminal")

        let emptyPathMatch = terminalNode.findDestination(for: [], at: 0, parameters: ["seed": "kept"])
        let consumedPathMatch = terminalNode.findDestination(for: ["terminal"], at: 1, parameters: [:])
        let terminalContainsEmptyPath = terminalNode.containsDestination(for: [], at: 0)
        let terminalContainsConsumedPath = terminalNode.containsDestination(for: ["terminal"], at: 1)
        let emptyNodeMatch = emptyNode.findDestination(for: [], at: 0, parameters: [:])
        let emptyNodeContainsEmptyPath = emptyNode.containsDestination(for: [], at: 0)
        let emptyPathResult = try #require(emptyPathMatch)
        let consumedPathResult = try #require(consumedPathMatch)

        #expect(emptyPathResult.destination.typeDescription == destination.typeDescription)
        #expect(emptyPathResult.parameter["seed"] as? String == "kept")
        #expect(consumedPathResult.destination.typeDescription == destination.typeDescription)
        #expect(terminalContainsEmptyPath)
        #expect(terminalContainsConsumedPath)
        #expect(emptyNodeMatch == nil)
        #expect(!emptyNodeContainsEmptyPath)
    }
}

private enum ParameterDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum StaticDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum DeepDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

private enum TerminalDestination: DestinationURLHandler {
    static let routeURLs: [URL] = []

    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}
