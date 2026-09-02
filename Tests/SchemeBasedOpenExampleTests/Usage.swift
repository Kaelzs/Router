//
//  Usage.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

final class TestableNavigationController: UINavigationController {
    let schemeName: String

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

final class TestableViewController: UIViewController {
    let parameters: [String: Any]
    let url: URL

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

enum TestableDestinationViewController: DestinationViewController {
    static let routeURLs: [URL] = []

    static func initialize(withParameters parameters: [String: Any], url: URL) throws -> UIViewController {
        TestableViewController(parameters: parameters, url: url)
    }
}

extension Router {
    @MainActor
    @discardableResult
    func open(_ urlString: String, parameters: [String: Any] = [:], animated: Bool = true, scheme: RouterScheme) throws -> OpenResult {
        var parameters = parameters
        parameters[SchemeBasedRouterOpenHandler.routerParameterKey] = scheme
        return try open(urlString, parameters: parameters, animated: animated)
    }
}

@MainActor
@Test("Opens routes in the selected navigation scheme")
func opensRoutesInSelectedNavigationScheme() throws {
    let mainNavigationController = TestableNavigationController(schemeName: "main")
    let mainScheme = RouterScheme(name: "main", navigationGenerator: { mainNavigationController })
    let router = Router(openHandler: SchemeBasedRouterOpenHandler(rootNavigationController: mainNavigationController))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
    window.rootViewController = mainNavigationController
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    try router.register(URL(string: "router://page.router/home")!, destination: .viewController(TestableDestinationViewController.self))
    try router.register(URL(string: "router://page.router/settings")!, destination: .viewController(TestableDestinationViewController.self))

    try router.register(URL(string: "router://page.router/user/login")!, destination: .viewController(TestableDestinationViewController.self))
    try router.register(URL(string: "router://page.router/user/verify")!, destination: .viewController(TestableDestinationViewController.self))

    _ = try router.open("router://page.router/home", animated: false, scheme: mainScheme)

    let mainNavigationControllerFromHandler = try #require((router.openHandler as? SchemeBasedRouterOpenHandler)?.navigationControllers["main"]?.object as? TestableNavigationController)

    #expect(mainNavigationControllerFromHandler.viewControllers.count == 1)
    #expect(mainNavigationControllerFromHandler.schemeName == "main")

    _ = try router.open("router://page.router/settings", animated: false, scheme: mainScheme)

    #expect(mainNavigationControllerFromHandler.viewControllers.count == 2)
    let settingsPage = try #require(mainNavigationControllerFromHandler.viewControllers.last as? TestableViewController)
    #expect(settingsPage.url.absoluteString == "router://page.router/settings")

    _ = try router.open("router://page.router/user/login", animated: false, scheme: .user)

    let userNavigationController = try #require((router.openHandler as? SchemeBasedRouterOpenHandler)?.navigationControllers["user"]?.object as? TestableNavigationController)

    #expect(userNavigationController.viewControllers.count == 1)
}
