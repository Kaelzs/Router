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

open class Router {
    var middlewares: NCArray<Middleware>
    var rootNode = RouterTreeNode(pathComponent: "")
    public private(set) var openHandler: RouterOpenHandler

    public init(openHandler: RouterOpenHandler) {
        self.rootNode = RouterTreeNode(pathComponent: "")
        self.middlewares = .init(count: 2)
        self.openHandler = openHandler
    }

    @MainActor
    @discardableResult
    public func open(_ urlString: String, parameters: [String: Any] = [:], animated: Bool = true) throws(RouterError) -> OpenResult? {
        guard let preOpenResult = try preOpen(urlString, parameters: parameters) else {
            throw .notHandled
        }

        switch preOpenResult.destination {
        case .viewController(let destinationViewController):
            let parameters = try middlewares.reduce(preOpenResult.parameters) { parameters, middleware throws(RouterError) in
                let handle = middleware.afterFinding(destinationViewController, parameter: parameters, originalURL: preOpenResult.url, router: self)

                switch handle {
                case .allow(let newParameters):
                    return newParameters
                case .block:
                    throw RouterError.blockedByMiddleware(middleware)
                }
            }

            do {
                try openHandler.performJump(parameter: parameters, animated: animated, url: preOpenResult.url, destination: destinationViewController)
            } catch {
                throw .viewControllerNotInitialized(error)
            }
        case .urlHandler(let urlHandler):
            let parameters = try middlewares.reduce(preOpenResult.parameters) { parameters, middleware throws(RouterError) in
                let handle = middleware.afterFinding(urlHandler, parameter: parameters, originalURL: preOpenResult.url, router: self)

                switch handle {
                case .allow(let newParameters):
                    return newParameters
                case .block:
                    throw RouterError.blockedByMiddleware(middleware)
                }
            }

            do {
                try urlHandler.handle(withParameters: parameters, url: preOpenResult.url)
            } catch {
                throw .urlHandlerNotHandled(error)
            }
        }
        return (preOpenResult.url, preOpenResult.destination, preOpenResult.parameters)
    }

    public typealias OpenResult = (url: URL, destination: Destination, parameters: [String: Any])

    public func preOpen(_ urlString: String, parameters: [String: Any]) throws(RouterError) -> OpenResult? {
        let (urlString, parameters) = middlewares.reduce((urlString, parameters)) { partialResult, middleware in
            middleware.prepare(string: partialResult.0, parameter: partialResult.1, router: self)
        }
        guard let escapedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: escapedString) else {
            throw .invalidURL(urlString)
        }

        if let internalResult = rootNodeSearch(url, parameters: parameters) {
            return (url, internalResult.destination, internalResult.parameter)
        } else {
            return nil
        }
    }

    public func register(_ middleware: consuming Middleware) {
        middlewares.append(middleware)
    }

    public func register(_ destinationViewController: DestinationViewController.Type) {
        register(.viewController(destinationViewController))
    }

    public func register(_ destinationURLHandler: DestinationURLHandler.Type) {
        register(.urlHandler(destinationURLHandler))
    }

    func register(_ destination: Destination) {
        for url in destination.routeURLs {
            register(url, destination: destination)
        }
    }

    func register(_ url: URL, destination: Destination) {
        guard let scheme = url.scheme,
              let host = url.host else {
            assertionFailure("Invalid URL")
            return
        }

        rootNode.append(parts: [scheme, host] + url.pathComponents, destination: destination)
    }

    func rootNodeSearch(_ url: URL, parameters: [String: Any]) -> DestinationFindResult? {
        guard let scheme = url.scheme,
              let host = url.host else {
            return nil
        }

        let searching = [scheme, host] + url.pathComponents

        var parameters: [String: Any] = parameters

        // Parameters priority
        // path parameters > user input parameters > query parameter
        // user input parameters should not override path parameter

        if let queryString = url.query {
            let queries = queryString.components(separatedBy: "&")

            for query in queries {
                let kvPair = query.components(separatedBy: "=")

                assert(kvPair.count == 2, "Invalid query string")
                guard let key = kvPair.first,
                      let value = kvPair.last else {
                    continue
                }

                // TODO: - Support array parameters if needed.
                assert(!key.contains("[]"), "Array parameters is not supported")

                if parameters[key] == nil {
                    parameters[key] = value
                }
            }
        }

        return rootNode.findDestination(for: searching, parameters: parameters)
    }
}
