//
//  Router.swift
//  Router
//
//  Created by Kael on 2024/10/30.
//

import Foundation

public enum RouterError: Error {
    case invalidURL(String)
    case blockedByMiddleware(any Middleware)
    case viewControllerNotInitialized(Error)
    case urlHandlerNotHandled(Error)

    case notHandled
}

public final class Router {
    private var middlewares: NCArray<Middleware>
    private var rootNode: RouterTreeNode
    private let coordinator: RouterReadWriteLock
    public let openHandler: any RouterOpenHandler

    public init(openHandler: any RouterOpenHandler) {
        self.rootNode = RouterTreeNode(pathComponent: "")
        self.middlewares = .init(count: 2)
        self.openHandler = openHandler
        self.coordinator = RouterReadWriteLock()
    }

    // Test-only injection point for observing contention warnings and synchronizing waiter state.
    init(openHandler: any RouterOpenHandler, contentionReporter: @escaping RouterReadWriteLock.ContentionReporter, waiterObservation: RouterReadWriteLock.WaiterObservation? = nil) {
        self.rootNode = RouterTreeNode(pathComponent: "")
        self.middlewares = .init(count: 2)
        self.openHandler = openHandler
        self.coordinator = RouterReadWriteLock(contentionReporter: contentionReporter, waiterObservation: waiterObservation)
    }

    @MainActor
    @discardableResult
    public func open(_ urlString: String, parameters: [String: Any] = [:], animated: Bool = true) throws(RouterError) -> OpenResult {
        let result = try coordinator.withReadAccess {
            () throws(RouterError) -> OpenResult in
            guard let preOpenResult = try preOpenWithReadAccessAlreadyHeld(urlString, parameters: parameters) else {
                throw .notHandled
            }

            let finalParameters = try middlewares.reduce(preOpenResult.parameters) { parameters, middleware throws(RouterError) in
                let strategy: MiddlewareHandledStrategy
                switch preOpenResult.destination {
                case .viewController(let destinationViewController):
                    strategy = middleware.afterFinding(destinationViewController, parameters: parameters, originalURL: preOpenResult.url, router: self)
                case .urlHandler(let urlHandler):
                    strategy = middleware.afterFinding(urlHandler, parameters: parameters, originalURL: preOpenResult.url, router: self)
                }

                switch strategy {
                case .allow(let newParameters):
                    return newParameters
                case .block:
                    throw .blockedByMiddleware(middleware)
                }
            }

            return (preOpenResult.url, preOpenResult.destination, finalParameters)
        }

        switch result.destination {
        case .viewController(let destinationViewController):
            do {
                try openHandler.performJump(parameters: result.parameters, animated: animated, url: result.url, destination: destinationViewController)
            } catch {
                throw .viewControllerNotInitialized(error)
            }
        case .urlHandler(let urlHandler):
            do {
                try urlHandler.handle(withParameters: result.parameters, url: result.url)
            } catch {
                throw .urlHandlerNotHandled(error)
            }
        }
        return result
    }

    public typealias OpenResult = (url: URL, destination: Destination, parameters: [String: Any])

    public func preOpen(_ urlString: String, parameters: [String: Any]) throws(RouterError) -> OpenResult? {
        return try coordinator.withReadAccess {
            () throws(RouterError) -> OpenResult? in
            try preOpenWithReadAccessAlreadyHeld(urlString, parameters: parameters)
        }
    }

    private func preOpenWithReadAccessAlreadyHeld(_ urlString: String, parameters: [String: Any]) throws(RouterError) -> OpenResult? {
        let prepared = middlewares.reduce((urlString, parameters)) {
            partialResult, middleware in
            middleware.prepare(string: partialResult.0, parameters: partialResult.1, router: self)
        }
        let parsed = try RouterURLParser.parseRuntime(prepared.0)
        var parameters = prepared.1

        for (key, value) in parsed.queryParameters where parameters[key] == nil {
            parameters[key] = value
        }

        guard let result = rootNode.findDestination(for: parsed.routeComponents, at: 0, parameters: parameters) else {
            return nil
        }

        return (parsed.url, result.destination, result.parameter)
    }

    public func register(_ middleware: consuming Middleware) throws(RouterRegistrationError) {
        let pendingMiddleware = PendingMiddleware(middleware)
        try coordinator.withWriteAccess { () throws(RouterRegistrationError) in
            middlewares.append(pendingMiddleware.take())
        }
    }

    public func register(_ destinationViewController: DestinationViewController.Type) throws(RouterRegistrationError) {
        _ = try register(destinationViewController.routeURLs, destination: .viewController(destinationViewController))
    }

    public func register(_ destinationURLHandler: DestinationURLHandler.Type) throws(RouterRegistrationError) {
        _ = try register(destinationURLHandler.routeURLs, destination: .urlHandler(destinationURLHandler))
    }

    @discardableResult
    func register(_ destination: Destination) throws(RouterRegistrationError) -> Int {
        try register(destination.routeURLs, destination: destination)
    }

    @discardableResult
    func register(_ url: URL, destination: Destination) throws(RouterRegistrationError) -> Int {
        try register([url], destination: destination)
    }

    @discardableResult
    func register(_ urls: [URL], destination: Destination) throws(RouterRegistrationError) -> Int {
        var parsedRoutes: [ParsedRouteURL] = []
        parsedRoutes.reserveCapacity(urls.count)

        for url in urls {
            do {
                parsedRoutes.append(try RouterURLParser.parseRoute(url))
            } catch let error {
                try failRegistration(with: error)
            }
        }

        var normalizedRoutes: Set<[String]> = []
        normalizedRoutes.reserveCapacity(parsedRoutes.count)
        for parsedRoute in parsedRoutes {
            guard normalizedRoutes.insert(parsedRoute.routeComponents).inserted else {
                try failRegistration(with: .duplicateRoute(parsedRoute.originalURL))
            }
        }

        return try coordinator.withWriteAccess {
            () throws(RouterRegistrationError) -> Int in
            for parsedRoute in parsedRoutes {
                guard !rootNode.containsDestination(for: parsedRoute.routeComponents, at: 0) else {
                    try failRegistration(with: .duplicateRoute(parsedRoute.originalURL))
                }
            }

            for parsedRoute in parsedRoutes {
                rootNode.append(parts: parsedRoute.routeComponents, destination: destination)
            }
            return parsedRoutes.count
        }
    }

    private func failRegistration(with error: RouterRegistrationError) throws(RouterRegistrationError) -> Never {
        assertionFailure(String(describing: error))
        throw error
    }
}

// `coordinator` protects the mutable trie and middleware storage. The handler
// reference is immutable and every RouterOpenHandler is Sendable.
extension Router: @unchecked Sendable {}

private final class PendingMiddleware {
    private var value: (any Middleware)?

    init(_ value: consuming any Middleware) {
        self.value = consume value
    }

    func take() -> any Middleware {
        guard let value = value.take() else {
            preconditionFailure("A middleware registration can only be consumed once")
        }
        return value
    }
}
