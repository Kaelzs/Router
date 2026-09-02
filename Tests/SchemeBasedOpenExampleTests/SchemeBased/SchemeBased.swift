//
//  SchemeBased.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

import Router
import UIKit

struct RouterScheme: Sendable {
    let name: String
    let navigationGenerator: @MainActor @Sendable () -> UINavigationController
}

extension RouterScheme {
    // Reserved scheme for the current navigation controller.
    static let current = RouterScheme(name: "current", navigationGenerator: { preconditionFailure("The current scheme does not create a navigation controller") })
}

enum SchemeBasedRouterError: Error {
    case invalidScheme
}

@MainActor
final class SchemeBasedRouterOpenHandler: RouterAlwaysOpenHandler {
    static let routerParameterKey = "_router.scheme"

    private(set) var navigationControllers: [String: Weak<UINavigationController>] = [:]
    private let rootNavigationController: UINavigationController

    init(rootNavigationController: UINavigationController) {
        self.rootNavigationController = rootNavigationController
    }

    private func findCurrentNavigationController() -> UINavigationController? {
        let current = rootNavigationController.presentedViewController ?? rootNavigationController
        return current as? UINavigationController
    }

    private func navigationController(for scheme: RouterScheme) -> UINavigationController {
        // If the scheme is the current scheme, return the current navigation controller.
        // This is the simplest way to find the current navigation controller.
        // In app context, you may have a more complex way to find the current navigation controller.
        if scheme.name == "current" {
            guard let navigationController = findCurrentNavigationController() else {
                preconditionFailure("The current navigation controller is not set")
            }
            return navigationController
        }

        if let navigationController = navigationControllers[scheme.name]?.object {
            return navigationController
        }

        let navigationController = scheme.navigationGenerator()
        navigationControllers[scheme.name] = Weak(navigationController)
        return navigationController
    }

    func performJump(viewController: UIViewController, parameters: [String: Any], animated: Bool) throws {
        guard let scheme = parameters[Self.routerParameterKey] as? RouterScheme else {
            throw SchemeBasedRouterError.invalidScheme
        }
        let navigationController = navigationController(for: scheme)
        navigationController.pushViewController(viewController, animated: animated)

        let currentNavigationController = findCurrentNavigationController()
        if currentNavigationController != navigationController {
            currentNavigationController?.present(navigationController, animated: animated)
        }
    }
}
