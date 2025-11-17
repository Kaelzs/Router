//
//  RouterTest.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

class NonOpeningHandler: RouterOpenHandler {
    func performJump(parameter: [String : Any], animated: Bool, url: URL, destination: any DestinationViewController.Type) throws {
        
    }
}

class TestableDestinationType: DestinationURLHandler {
    // We use the internal method to register this destination for specific url.
    static var routeURLs: [URL] { [] }

    static func handle(withParameters parameters: [String: Any], url: URL) throws {
        // do nothing
    }
}

extension Destination: Equatable {
    public static func == (lhs: Destination, rhs: Destination) -> Bool {
        return lhs.typeDescription == rhs.typeDescription
    }
}

struct TestError: Error {
    var message: String

    init(_ message: String) {
        self.message = message
    }
}

@Test("register and search")
func registerAndSearch() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(URL(string: "router://page.router/settings")!, destination: .urlHandler(TestableDestinationType.self))
    router.register(URL(string: "router://page.router/settings/detailedPage")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings", parameters: [:]))

    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
}

@Test("parameters path")
func parameterPath() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(URL(string: "router://page.router/user/:id")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/user/123", parameters: [:]))

    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
    #expect((preOpenResult.parameters["id"] as? String) == "123")
}

struct ModifingMiddleware: Middleware {
    func prepare(string: String, parameter: [String: Any]) -> (string: String, parameter: [String: Any]) {
        ("router://modified.page", [:])
    }
}

@Test("middleware modification")
func middlewareModification() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(ModifingMiddleware())
    router.register(URL(string: "router://modified.page")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings", parameters: [:]))

    #expect(preOpenResult.url.absoluteString == "router://modified.page")
    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
}

struct BlockingMiddleware: Middleware {
    func beforeHandle(_ destination: any DestinationURLHandler.Type, parameter: [String: Any], originalURL: URL) -> MiddlewareHandledStrategy {
        .block
    }
}

@Test("middleware block")
func middlewareBlock() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(BlockingMiddleware())
    router.register(URL(string: "router://page.router/settings")!, destination: .urlHandler(TestableDestinationType.self))

    do {
        _ = try router.preOpen("router://page.router/settings", parameters: [:])
        throw TestError("Should throw")
    } catch {
        guard case .blockedByMiddleware(let middleware) = error as? RouterError else {
            throw TestError("Should be blocked by middleware")
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

    func prepare(string: String, parameter: [String: Any]) -> (string: String, parameter: [String: Any]) {
        (appStoreURLRewrite(string), parameter)
    }
}

@available(iOS 16.0, *)
@Test("app store rewrite")
func appStoreRewrite() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(AppStoreRewriteMiddleware())
    router.register(URL(string: "appstore://apple.com/app/:id")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("https://apps.apple.com/app/id2343432205", parameters: [:]))

    #expect(preOpenResult.url.absoluteString == "appstore://apple.com/app/2343432205")
    #expect((preOpenResult.parameters["id"] as? String) == "2343432205")
    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
}
