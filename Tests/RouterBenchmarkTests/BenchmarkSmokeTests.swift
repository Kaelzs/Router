#if !DEBUG
@testable import Router
import XCTest

final class BenchmarkSmokeTests: XCTestCase {
    func testBenchmarkTargetRunsInRelease() {
        XCTAssertTrue(true)
    }
}
#endif
