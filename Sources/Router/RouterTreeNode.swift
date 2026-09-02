//
//  RouterTreeNode.swift
//  Router
//
//  Created by Kael on 2024/10/30.
//

import Foundation

typealias DestinationFindResult = (destination: Destination, parameter: [String: Any])

struct RouterTreeNode: ~Copyable {
    private var children: NCArray<RouterTreeNode> = .init(count: 2)
    let pathComponent: String
    let isParameter: Bool
    var destination: Destination?

    var parameterName: String {
        String(pathComponent.dropFirst())
    }

    init(pathComponent: String, destination: Destination? = nil) {
        self.pathComponent = pathComponent
        self.isParameter = pathComponent.starts(with: ":")
        self.destination = destination
    }

    mutating func append(childNode: consuming RouterTreeNode) {
        // We append the parameter node for better loop search.
        if childNode.isParameter {
            children.append(childNode)
        } else {
            children.insert(childNode, at: 0)
        }
    }

    mutating func append(parts: [String], destination: Destination) {
        append(parts: parts, at: 0, destination: destination)
    }

    mutating func append(parts: [String], at index: Int, destination: Destination) {
        guard index >= 0, index < parts.count else {
            assertionFailure("Empty parts")
            return
        }

        let pathComponent = parts[index]
        let findIndex = children.firstIndex { node in
            node.pathComponent == pathComponent
        }

        if let findIndex {
            children.updateElement(at: findIndex) { node in
                if index + 1 == parts.count {
                    if node.destination == nil {
                        node.destination = destination
                    } else {
                        assertionFailure("Destination already exists")
                    }
                } else {
                    node.append(parts: parts, at: index + 1, destination: destination)
                }
            }
        } else {
            if index + 1 == parts.count {
                let newNode = RouterTreeNode(pathComponent: pathComponent, destination: destination)
                append(childNode: newNode)
            } else {
                var newNode = RouterTreeNode(pathComponent: pathComponent)
                newNode.append(parts: parts, at: index + 1, destination: destination)
                append(childNode: newNode)
            }
        }
    }

    func findDestination(for pathComponents: [String], parameters: [String: Any]) -> DestinationFindResult? {
        findDestination(for: pathComponents, at: 0, parameters: parameters)
    }

    func findDestination(for pathComponents: [String], at index: Int, parameters: [String: Any]) -> DestinationFindResult? {
        guard index >= 0, index <= pathComponents.count else {
            assertionFailure("Path index out of bounds")
            return nil
        }

        guard index < pathComponents.count else {
            return destination.map { ($0, parameters) }
        }

        let pathComponent = pathComponents[index]

        return children.first { node in
            if node.isParameter {
                return true
            } else {
                return node.pathComponent == pathComponent
            }
        } using: { node in
            var parameters = parameters
            if node.isParameter {
                parameters[node.parameterName] = pathComponent
            }
            return node.findDestination(for: pathComponents, at: index + 1, parameters: parameters)
        } notFound: {
            nil
        }
    }

    func containsDestination(for pathComponents: [String], at index: Int) -> Bool {
        guard index >= 0, index <= pathComponents.count else {
            assertionFailure("Path index out of bounds")
            return false
        }

        guard index < pathComponents.count else {
            return destination != nil
        }

        let pathComponent = pathComponents[index]
        return children.first { node in
            node.pathComponent == pathComponent
        } using: { node in
            node.containsDestination(for: pathComponents, at: index + 1)
        } notFound: {
            false
        }
    }
}

extension RouterTreeNode {
    var stepIndent: String {
        "  "
    }

    func treeDescription(indent: String = "") -> String {
        let childrenDescription = children.isEmpty ? "" : ("\(indent + stepIndent)|-\n" + children.reduce("") { result, node in
            result + node.treeDescription(indent: indent + stepIndent) + "\n"
        }).dropLast()
        return
            """
            \(indent)\(pathComponent.isEmpty ? "" : (pathComponent + " "))\(isParameter ? "P" : "N") \(destination != nil ? "\(destination!.typeDescription)" : "NO")
            \(childrenDescription)
            """
    }
}
