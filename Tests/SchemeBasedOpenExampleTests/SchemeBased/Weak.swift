//
//  Weak.swift
//  Router
//
//  Created by Kael on 2024/11/1.
//

final class Weak<Object: AnyObject>: Hashable {
    private weak var weakReference: Object?
    private let id: ObjectIdentifier

    var object: Object? {
        weakReference
    }

    init(_ object: Object) {
        weakReference = object
        id = ObjectIdentifier(object)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Weak<Object>, rhs: Weak<Object>) -> Bool {
        lhs.id == rhs.id
    }
}
