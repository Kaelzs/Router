//
//  RouterTests.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

final class NoOpOpenHandler: RouterOpenHandler, Sendable {
    func performJump(parameters: [String: Any], animated: Bool, url: URL, destination: any DestinationViewController.Type) throws {}
}

enum TestURLHandler: DestinationURLHandler {
    static let routeURLs: [URL] = []

    static func handle(withParameters parameters: [String: Any], url: URL) throws {}
}

@Test("Registers and finds a route")
func registersAndFindsRoute() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(URL(string: "router://page.router/settings")!, destination: .urlHandler(TestURLHandler.self))
    try router.register(URL(string: "router://page.router/settings/detailedPage")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings", parameters: [:]))

    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
}

@Test("Extracts a path parameter")
func extractsPathParameter() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(URL(string: "router://page.router/user/:id")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/user/123", parameters: [:]))

    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
    #expect(preOpenResult.parameters["id"] as? String == "123")
}

struct ModifyingMiddleware: Middleware {
    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        ("router://modified.page", [:])
    }
}

@Test("Middleware rewrites a URL")
func middlewareRewritesURL() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(ModifyingMiddleware())
    try router.register(URL(string: "router://modified.page")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings", parameters: [:]))

    #expect(preOpenResult.url.absoluteString == "router://modified.page")
    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
}

struct BlockingMiddleware: Middleware {
    @MainActor
    func afterFinding(_ destination: any DestinationURLHandler.Type, parameters: [String: Any], originalURL: URL, router: Router) -> MiddlewareHandledStrategy {
        .block
    }
}

@MainActor
@Test("Middleware blocks a route")
func middlewareBlocksRoute() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(BlockingMiddleware())
    try router.register(URL(string: "router://page.router/settings")!, destination: .urlHandler(TestURLHandler.self))

    do {
        _ = try router.open("router://page.router/settings", parameters: [:])
        Issue.record("Expected middleware to block the route")
    } catch {
        guard case .blockedByMiddleware(let middleware) = error else {
            Issue.record("Unexpected router error: \(error)")
            return
        }
        #expect(type(of: middleware) == BlockingMiddleware.self)
    }
}

@available(iOS 16.0, *)
struct AppStoreRewriteMiddleware: Middleware {
    func appStoreURLRewrite(_ urlString: String) -> String {
        let regex = /^https?:\/\/[^\/]*?(itunes|apps)\.apple\.com\/(.*\/)?(developer|app)\/.*?(id(\d+))$/
        let matchResult = try? regex.firstMatch(in: urlString)

        if let id = matchResult?.output.5 {
            return "appstore://apple.com/app/\(id)"
        }

        return urlString
    }

    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        (appStoreURLRewrite(string), parameters)
    }
}

@available(iOS 16.0, *)
@Test("Rewrites an App Store URL")
func appStoreRewrite() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(AppStoreRewriteMiddleware())
    try router.register(URL(string: "appstore://apple.com/app/:id")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("https://apps.apple.com/app/id2343432205", parameters: [:]))

    #expect(preOpenResult.url.absoluteString == "appstore://apple.com/app/2343432205")
    #expect(preOpenResult.parameters["id"] as? String == "2343432205")
    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
}
