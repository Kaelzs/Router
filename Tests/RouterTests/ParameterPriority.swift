//
//  ParameterPriority.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

@Test("Parameter Priority - path > user input")
func testParameterPriority1() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(URL(string: "router://page.router/settings/:section")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings/purchase", parameters: ["section": "privacy"]))

    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
    #expect(preOpenResult.parameters["section"] as? String == "purchase")
}

@Test("Parameter Priority - user input > query")
func testParameterPriority2() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(URL(string: "router://page.router/settings")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings?section=purchase", parameters: ["section": "privacy"]))

    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))

    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
    // The user input should have higher priority than the query.
    #expect(preOpenResult.parameters["section"] as? String == "privacy")
}

@Test("Parameter Priority - path > query")
func testParameterPriority3() throws {
    let router = Router(openHandler: NonOpeningHandler())

    router.register(URL(string: "router://page.router/settings/:section")!, destination: .urlHandler(TestableDestinationType.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings/purchase?section=privacy", parameters: ["section": "privacy"]))

    #expect(preOpenResult.destination == .urlHandler(TestableDestinationType.self))
    // The path should have higher priority than the query.
    #expect(preOpenResult.parameters["section"] as? String == "purchase")
}
