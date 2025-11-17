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
    func prepare(string: String, parameter: [String: Any]) -> (string: String, parameter: [String: Any])

    func beforeInitialize(_ destination: DestinationViewController.Type, parameter: [String: Any], originalURL: URL) -> MiddlewareHandledStrategy

    func afterInitialize<Destination: DestinationViewController>(_ destination: Destination, parameter: [String: Any], originalURL: URL, initializedViewController: UIViewController)

    func beforeHandle(_ destination: DestinationURLHandler.Type, parameter: [String: Any], originalURL: URL) -> MiddlewareHandledStrategy
}

public extension Middleware {
    func prepare(string: String, parameter: [String: Any]) -> (string: String, parameter: [String: Any]) {
        return (string: string, parameter: parameter)
    }

    func beforeInitialize(_ destination: DestinationViewController.Type, parameter: [String: Any], originalURL: URL) -> MiddlewareHandledStrategy {
        return .allow(parameters: parameter)
    }

    func afterInitialize<Destination: DestinationViewController>(_ destination: Destination, parameter: [String: Any], originalURL: URL, initializedViewController: UIViewController) {
        return
    }

    func beforeHandle(_ destination: DestinationURLHandler.Type, parameter: [String: Any], originalURL: URL) -> MiddlewareHandledStrategy {
        return .allow(parameters: parameter)
    }
}
