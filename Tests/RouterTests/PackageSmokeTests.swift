@testable import Router
import Testing

@Test("Router package can be constructed")
func routerPackageCanBeConstructed() {
    _ = Router(openHandler: TestOpenHandler())
}
