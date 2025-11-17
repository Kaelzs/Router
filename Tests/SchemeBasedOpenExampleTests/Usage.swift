//
//  Usage.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

class TestableNavigationController: UINavigationController {
    var schemeName: String

    init(schemeName: String) {
        self.schemeName = schemeName
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RouterScheme {
    static let user = RouterScheme(name: "user", navigationGenerator: { TestableNavigationController(schemeName: "user") })
}

class TestableViewController: UIViewController {
    var parameters: [String: Any] = [:]
    var url: URL

    init(parameters: [String: Any], url: URL) {
        self.parameters = parameters
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TestableDestinationViewController: DestinationViewController {
    // We use the internal method to register this destination for specific url.
    static var routeURLs: [URL] { [] }

    static func initialize(withParameters parameters: [String: Any], url: URL) throws -> UIViewController {
        TestableViewController(parameters: parameters, url: url)
    }
}

extension Router {
    @MainActor
    @discardableResult
    func open(_ urlString: String, parameters: [String: Any] = [:], animated: Bool = true, scheme: RouterScheme) throws -> OpenResult? {
        var parameters = parameters
        parameters[SchemeBasedRouterOpenHandler.routerParameterKey] = scheme
        return try open(urlString, parameters: parameters, animated: animated)
    }
}

@MainActor
@Test("scheme based open")
func testSchemeBasedOpen() throws {
    let mainNavigationController = TestableNavigationController(schemeName: "main")
    let mainScheme = RouterScheme(name: "main", navigationGenerator: { mainNavigationController })
    let router = Router(openHandler: SchemeBasedRouterOpenHandler(rootNavigationController: mainNavigationController))

    router.register(URL(string: "router://page.router/home")!, destination: .viewController(TestableDestinationViewController.self))
    router.register(URL(string: "router://page.router/settings")!, destination: .viewController(TestableDestinationViewController.self))

    router.register(URL(string: "router://page.router/user/login")!, destination: .viewController(TestableDestinationViewController.self))
    router.register(URL(string: "router://page.router/user/verify")!, destination: .viewController(TestableDestinationViewController.self))

    _ = try #require(try router.open("router://page.router/home", animated: false, scheme: mainScheme))

    let mainNavigationControllerFromHandler = try #require((router.openHandler as? SchemeBasedRouterOpenHandler)?.navigationControllers["main"]?.object as? TestableNavigationController)

    #expect(mainNavigationControllerFromHandler.viewControllers.count == 1)
    #expect(mainNavigationControllerFromHandler.schemeName == "main")

    _ = try #require(try router.open("router://page.router/settings", animated: false, scheme: mainScheme))

    #expect(mainNavigationControllerFromHandler.viewControllers.count == 2)
    let settingsPage = try #require(mainNavigationControllerFromHandler.viewControllers.last as? TestableViewController)
    #expect(settingsPage.url.absoluteString == "router://page.router/settings")

    _ = try #require(try router.open("router://page.router/user/login", animated: false, scheme: .user))

    let userNavigationController = try #require((router.openHandler as? SchemeBasedRouterOpenHandler)?.navigationControllers["user"]?.object as? TestableNavigationController)

    #expect(userNavigationController.viewControllers.count == 1)
}
