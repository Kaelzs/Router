//
//  Destination.swift
//  Router
//
//  Created by Kael on 2024/10/31.
//

import Foundation
import UIKit

public protocol DestinationType {
    static var routeURLs: [URL] { get }
}

public protocol DestinationViewController: DestinationType {
    @MainActor
    static func initialize(withParameters parameters : [String: Any], url: URL) throws -> UIViewController
}

public protocol DestinationURLHandler: DestinationType {
    @MainActor
    static func handle(withParameters parameters: [String: Any], url: URL) throws
}

public enum Destination {
    case viewController(DestinationViewController.Type)
    case urlHandler(DestinationURLHandler.Type)

    var routeURLs: [URL] {
        switch self {
        case .viewController(let destinationViewController):
            return destinationViewController.routeURLs
        case .urlHandler(let destinationURLHandler):
            return destinationURLHandler.routeURLs
        }
    }

    var typeDescription: String {
        switch self {
        case .viewController(let destinationViewController):
            return "VC-" + String(describing: destinationViewController)
        case .urlHandler(let destinationURLHandler):
            return "HD-" + String(describing: destinationURLHandler)
        }
    }
}
