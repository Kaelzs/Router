import Router
import Testing
import UIKit

private func requireSendable<T: Sendable>(_ value: T) {}

@MainActor
@Test("public handler API is externally constructible and Sendable")
func publicHandlerAPIIsExternallyConstructibleAndSendable() {
    let navigationController = UINavigationController()
    let defaultHandler = DefaultOpenHandler(navigationController: navigationController)
    let router = Router(openHandler: defaultHandler)
    let handler: any RouterOpenHandler = router.openHandler

    requireSendable(defaultHandler)
    requireSendable(handler)
    requireSendable(router)
}
