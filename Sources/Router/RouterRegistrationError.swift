import Foundation

public enum RouterRegistrationError: Error {
    case invalidRouteURL(URL)
    case duplicateRoute(URL)
    case reentrantRegistration
}
