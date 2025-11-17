//
//  UIUsage.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

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

@MainActor
@Test("push to new view controller")
func testPushToNewViewController() throws {
    let openHandler = DefaultOpenHandler(navigationController: UINavigationController())
    let router = Router(openHandler: openHandler)

    router.register(URL(string: "router://page.router/main/:moreInfo")!, destination: .viewController(TestableDestinationViewController.self))

    let openResult = try #require(try router.open("router://page.router/main/page1", parameters: ["testing": 123], animated: false))

    #expect(openResult.destination == .viewController(TestableDestinationViewController.self))
    #expect(openHandler.navigationController.viewControllers.count == 1)

    let testableViewController = try #require(openHandler.navigationController.viewControllers.first as? TestableViewController)
    #expect(testableViewController.parameters["testing"] as? Int == 123)
    #expect(testableViewController.parameters["moreInfo"] as? String == "page1")
    #expect(testableViewController.url.absoluteString == "router://page.router/main/page1")

    let openResult2 = try #require(try router.open("router://page.router/main/page2", parameters: ["testing": 456], animated: false))

    #expect(openResult2.destination == .viewController(TestableDestinationViewController.self))
    #expect(openHandler.navigationController.viewControllers.count == 2)

    let testableViewController2 = try #require(openHandler.navigationController.viewControllers[1] as? TestableViewController)
    #expect(testableViewController2.parameters["testing"] as? Int == 456)
    #expect(testableViewController2.parameters["moreInfo"] as? String == "page2")
    #expect(testableViewController2.url.absoluteString == "router://page.router/main/page2")
}
