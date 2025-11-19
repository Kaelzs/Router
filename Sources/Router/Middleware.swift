//
//  Middleware.swift
//  Router
//
//  Created by Kael on 2024/10/31.
//

import Foundation
import UIKit

public enum MiddlewareHandledStrategy {
    case allow(parameters: [String: Any])
    case block
}

public protocol Middleware: Sendable, ~Copyable {
    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any])

    @MainActor
    func afterFinding(_ destination: DestinationViewController.Type, parameters: [String: Any], originalURL: URL, router: Router) -> MiddlewareHandledStrategy

    @MainActor
    func afterFinding(_ destination: DestinationURLHandler.Type, parameters: [String: Any], originalURL: URL, router: Router) -> MiddlewareHandledStrategy
}

public extension Middleware {
    func prepare(string: String, parameters: [String: Any], router: Router) -> (string: String, parameters: [String: Any]) {
        return (string: string, parameters: parameters)
    }

    func afterFinding(_ destination: DestinationViewController.Type, parameters: [String: Any], originalURL: URL, router: Router) -> MiddlewareHandledStrategy {
        return .allow(parameters: parameters)
    }

    func afterFinding(_ destination: DestinationURLHandler.Type, parameters: [String: Any], originalURL: URL, router: Router) -> MiddlewareHandledStrategy {
        return .allow(parameters: parameters)
    }
}
