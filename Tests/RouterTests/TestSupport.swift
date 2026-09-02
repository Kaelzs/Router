@testable import Router
import Foundation

final class TestOpenHandler: RouterOpenHandler, Sendable {
    @MainActor
    func performJump(parameters: [String: Any], animated: Bool, url: URL, destination: any DestinationViewController.Type) throws {}
}
