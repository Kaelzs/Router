@testable import Router
import Foundation
import Testing

@Suite("Router URL parser")
struct RouterURLParserTests {
    struct ValidRouteCase: Sendable {
        let input: String
        let expectedComponents: [String]
    }

    @Test(
        "Route declarations form a canonical identity without changing the URL",
        arguments: [
            ValidRouteCase(input: "RoUtEr://Page.Router//Users///Profile/", expectedComponents: ["router", "page.router", "Users", "Profile"]),
            ValidRouteCase(input: "router://host/a%2Fb/%252F", expectedComponents: ["router", "host", "a/b", "%2F"]),
            ValidRouteCase(input: "router://[::1]/path", expectedComponents: ["router", "[::1]", "path"]),
            ValidRouteCase(input: "router://host/path:part", expectedComponents: ["router", "host", "path:part"]),
        ]
    )
    func parsesRouteDeclaration(testCase: ValidRouteCase) throws {
        let inputURL = try #require(URL(string: testCase.input))

        let parsed = try RouterURLParser.parseRoute(inputURL)

        #expect(parsed.originalURL == inputURL)
        #expect(parsed.routeComponents == testCase.expectedComponents)
    }

    @Test(
        "Route declarations reject non-hierarchical URLs and unsupported components",
        arguments: [
            "relative/path",
            "//host/path",
            "router:path",
            "router:///path",
            "router://user@host/path",
            "router://host:8080/path",
            "router://host/path?value=1",
            "router://host/path#details",
            "router://host/%FF",
        ]
    )
    func rejectsInvalidRouteDeclaration(input: String) throws {
        let inputURL = try #require(URL(string: input))

        do {
            _ = try RouterURLParser.parseRoute(inputURL)
            Issue.record("Expected \(input) to be rejected")
        } catch let error {
            guard case .invalidRouteURL(let rejectedURL) = error else {
                Issue.record("Unexpected registration error: \(error)")
                return
            }
            #expect(rejectedURL == inputURL)
        }
    }

    @Test
    func parsesRuntimeURLWithoutDoubleEncoding() throws {
        let input = "RoUtEr://Page.Router/user/a%2Fb?token=a%3Db&plus=a+b&once=%252F#details"

        let parsed = try RouterURLParser.parseRuntime(input)

        #expect(parsed.routeComponents == ["router", "page.router", "user", "a/b"])
        #expect(parsed.queryParameters["token"] == "a=b")
        #expect(parsed.queryParameters["plus"] == "a+b")
        #expect(parsed.queryParameters["once"] == "%2F")
        #expect(parsed.url.fragment == "details")
        #expect(parsed.url == URLComponents(string: input)?.url)
    }

    @Test
    func preservesRawPercentInRuntimePath() throws {
        let parsed = try RouterURLParser.parseRuntime("router://host/%ZZ")

        #expect(parsed.routeComponents == ["router", "host", "%ZZ"])
    }

    @Test
    func appliesRuntimeQueryRulesInSourceOrder() throws {
        let input = "router://host/path?item=first&item=second&flag&flag=value&empty=&equals=a=b=c"

        let parsed = try RouterURLParser.parseRuntime(input)

        #expect(parsed.queryParameters == [
            "item": "first",
            "flag": "value",
            "empty": "",
            "equals": "a=b=c",
        ])
        #expect(parsed.url == URLComponents(string: input)?.url)
    }

    @Test(
        "Runtime URLs reject invalid hierarchy, authority, percent escapes, and array keys",
        arguments: [
            "relative/path",
            "//host/path",
            "router:path",
            "router:///path",
            "router://user@host/path",
            "router://host:8080/path",
            "router://host/%FF",
            "router://host/path?value=%FF",
            "router://host/path?key%5B%5D=value",
        ]
    )
    func rejectsInvalidRuntimeURL(input: String) {
        do {
            _ = try RouterURLParser.parseRuntime(input)
            Issue.record("Expected \(input) to be rejected")
        } catch let error {
            guard case .invalidURL(let rejectedInput) = error else {
                Issue.record("Unexpected router error: \(error)")
                return
            }
            #expect(rejectedInput == input)
        }
    }
}
