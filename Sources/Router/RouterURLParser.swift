import Foundation

struct ParsedRouteURL {
    let originalURL: URL
    let routeComponents: [String]
}

struct ParsedRuntimeURL {
    let url: URL
    let routeComponents: [String]
    let queryParameters: [String: String]
}

enum RouterURLParser {
    static func parseRoute(_ url: URL) throws(RouterRegistrationError) -> ParsedRouteURL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let scheme = components.scheme,
        !scheme.isEmpty,
        let host = components.host,
        !host.isEmpty,
        components.percentEncodedUser == nil,
        components.percentEncodedPassword == nil,
        components.port == nil,
        !hasExplicitPort(in: url.absoluteString),
        components.percentEncodedQuery == nil,
        components.percentEncodedFragment == nil,
        let pathComponents = decodePath(components.percentEncodedPath) else {
            throw .invalidRouteURL(url)
        }

        return ParsedRouteURL(originalURL: url, routeComponents: [scheme.lowercased(), host.lowercased()] + pathComponents)
    }

    static func parseRuntime(_ string: String) throws(RouterError) -> ParsedRuntimeURL {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme,
              !scheme.isEmpty,
              let host = components.host,
              !host.isEmpty,
              components.percentEncodedUser == nil,
              components.percentEncodedPassword == nil,
              components.port == nil,
              !hasExplicitPort(in: string),
              let pathComponents = decodePath(components.percentEncodedPath),
              isDecodable(components.percentEncodedQuery),
              let url = components.url else {
            throw .invalidURL(string)
        }

        var queryParameters: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard !item.name.contains("[]") else {
                throw .invalidURL(string)
            }
            guard let value = item.value,
                  queryParameters[item.name] == nil else {
                continue
            }
            queryParameters[item.name] = value
        }

        return ParsedRuntimeURL(url: url, routeComponents: [scheme.lowercased(), host.lowercased()] + pathComponents, queryParameters: queryParameters)
    }

    private static func decodePath(_ percentEncodedPath: String) -> [String]? {
        var components: [String] = []
        for encodedComponent in percentEncodedPath.split(separator: "/") {
            guard let component = String(encodedComponent).removingPercentEncoding else {
                return nil
            }
            components.append(component)
        }
        return components
    }

    private static func isDecodable(_ percentEncodedQuery: String?) -> Bool {
        guard let percentEncodedQuery else {
            return true
        }
        return percentEncodedQuery.removingPercentEncoding != nil
    }

    private static func hasExplicitPort(in string: String) -> Bool {
        guard let schemeEnd = string.firstIndex(of: ":") else {
            return false
        }

        let firstSlash = string.index(after: schemeEnd)
        guard string[firstSlash...].hasPrefix("//") else {
            return false
        }

        let authorityStart = string.index(firstSlash, offsetBy: 2)
        let authorityEnd = string[authorityStart...].firstIndex { character in
            character == "/" || character == "?" || character == "#"
        } ?? string.endIndex
        let authority = string[authorityStart..<authorityEnd]
        let hostStart = authority.lastIndex(of: "@").map {
            authority.index(after: $0)
        } ?? authority.startIndex

        var isInsideBrackets = false
        for character in authority[hostStart...] {
            switch character {
            case "[":
                isInsideBrackets = true
            case "]":
                isInsideBrackets = false
            case ":" where !isInsideBrackets:
                return true
            default:
                continue
            }
        }
        return false
    }
}
