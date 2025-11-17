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
    let navigationGenerator: @MainActor () -> UINavigationController
}

extension RouterScheme {
    // Reserved scheme for the current navigation controller.
    static let current = RouterScheme(name: "current", navigationGenerator: { fatalError() })
}

enum SchemeBasedRouterError: Error {
    case invalidScheme
}

class SchemeBasedRouterOpenHandler: RouterAlwaysOpenHandler {
    static var routerParameterKey: String { "_router.scheme" }

    var navigationControllers: [String: Weak<UINavigationController>] = [:]
    let rootNavigationController: UINavigationController

    init(rootNavigationController: UINavigationController) {
        self.rootNavigationController = rootNavigationController
    }

    @MainActor
    private func findCurrentNavigationController() -> UINavigationController? {
        let current = rootNavigationController.presentedViewController ?? rootNavigationController
        return current as? UINavigationController
    }

    @MainActor
    private func navigationController(for scheme: RouterScheme) -> UINavigationController {
        // If the scheme is the current scheme, return the current navigation controller.
        // This is the simplest way to find the current navigation controller.
        // In app context, you may have a more complex way to find the current navigation controller.
        if scheme.name == "current" {
            let nav = findCurrentNavigationController()
            precondition(nav != nil, "The current navigation controller is not set.")
            return nav!
        }

        if let nav = navigationControllers[scheme.name]?.object {
            return nav
        } else {
            let nav = scheme.navigationGenerator()
            navigationControllers[scheme.name] = Weak(nav)
            return nav
        }
    }

    @MainActor
    func performJump(viewController: UIViewController, parameter: [String: Any], animated: Bool) throws {
        guard let scheme = parameter[Self.routerParameterKey] as? RouterScheme else {
            throw SchemeBasedRouterError.invalidScheme
        }
        let navigationController = self.navigationController(for: scheme)
        navigationController.pushViewController(viewController, animated: animated)

        let currentNavigationController = findCurrentNavigationController()
        if currentNavigationController != navigationController {
            currentNavigationController?.present(navigationController, animated: animated)
        }
    }
}
