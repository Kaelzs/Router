//
//  UIUsage.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

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

@MainActor
@Test("Pushes view controllers with resolved parameters")
func pushesViewControllersWithResolvedParameters() throws {
    let navigationController = UINavigationController()
    let openHandler = DefaultOpenHandler(navigationController: navigationController)
    let router = Router(openHandler: openHandler)

    try router.register(URL(string: "router://page.router/main/:moreInfo")!, destination: .viewController(TestableDestinationViewController.self))

    let openResult = try router.open("router://page.router/main/page1", parameters: ["testing": 123], animated: false)

    #expect(openResult.destination.typeDescription == Destination.viewController(TestableDestinationViewController.self).typeDescription)
    #expect(navigationController.viewControllers.count == 1)

    let testableViewController = try #require(navigationController.viewControllers.first as? TestableViewController)
    #expect(testableViewController.parameters["testing"] as? Int == 123)
    #expect(testableViewController.parameters["moreInfo"] as? String == "page1")
    #expect(testableViewController.url.absoluteString == "router://page.router/main/page1")

    let secondOpenResult = try router.open("router://page.router/main/page2", parameters: ["testing": 456], animated: false)

    #expect(secondOpenResult.destination.typeDescription == Destination.viewController(TestableDestinationViewController.self).typeDescription)
    #expect(navigationController.viewControllers.count == 2)

    let secondViewController = try #require(navigationController.viewControllers[1] as? TestableViewController)
    #expect(secondViewController.parameters["testing"] as? Int == 456)
    #expect(secondViewController.parameters["moreInfo"] as? String == "page2")
    #expect(secondViewController.url.absoluteString == "router://page.router/main/page2")
}
