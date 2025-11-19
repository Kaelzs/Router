//
//  OpenHandler.swift
//  Router
//
//  Created by Kael on 2024/10/31.
//

import UIKit

public protocol RouterOpenHandler {
    @MainActor
    func performJump(parameters: [String: Any], animated: Bool, url: URL, destination: DestinationViewController.Type) throws
}

public protocol RouterAlwaysOpenHandler: RouterOpenHandler {
    @MainActor
    func performJump(viewController: UIViewController, parameters: [String: Any], animated: Bool) throws
}

public extension RouterAlwaysOpenHandler {
    @MainActor
    func performJump(parameters: [String: Any], animated: Bool, url: URL, destination: any DestinationViewController.Type) throws {
        let viewController = try destination.initialize(withParameters: parameters, url: url)
        try performJump(viewController: viewController, parameters: parameters, animated: animated)
    }
}

public class DefaultOpenHandler: RouterAlwaysOpenHandler {
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    @MainActor
    public func performJump(viewController: UIViewController, parameters: [String : Any], animated: Bool) throws {
        navigationController.pushViewController(viewController, animated: animated)
    }
}
