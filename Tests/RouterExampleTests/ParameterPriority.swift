//
//  ParameterPriority.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

@testable import Router
import Testing
import UIKit

@Test("Path parameters override caller parameters")
func pathParameterOverridesCallerParameter() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(URL(string: "router://page.router/settings/:section")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings/purchase", parameters: ["section": "privacy"]))

    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
    #expect(preOpenResult.parameters["section"] as? String == "purchase")
}

@Test("Caller parameters override query parameters")
func callerParameterOverridesQueryParameter() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(URL(string: "router://page.router/settings")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings?section=purchase", parameters: ["section": "privacy"]))

    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
    #expect(preOpenResult.parameters["section"] as? String == "privacy")
}

@Test("Path parameters override query parameters")
func pathParameterOverridesQueryParameter() throws {
    let router = Router(openHandler: NoOpOpenHandler())

    try router.register(URL(string: "router://page.router/settings/:section")!, destination: .urlHandler(TestURLHandler.self))

    let preOpenResult = try #require(try router.preOpen("router://page.router/settings/purchase?section=privacy", parameters: [:]))

    #expect(preOpenResult.destination.typeDescription == Destination.urlHandler(TestURLHandler.self).typeDescription)
    #expect(preOpenResult.parameters["section"] as? String == "purchase")
}
