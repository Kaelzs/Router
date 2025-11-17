//
//  Weak.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

public class Weak<T>: Hashable {
    weak var weakRef: AnyObject?

    public var object: T? {
        weakRef as? T
    }

    let id: ObjectIdentifier

    public init(_ obj: T) {
        let object: AnyObject = obj as AnyObject
        weakRef = object
        id = ObjectIdentifier(object)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }

    public static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        lhs.id == rhs.id
    }
}
