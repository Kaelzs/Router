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
        guard let first = parts.first else {
            assertionFailure("Empty parts")
            return
        }

        let findIndex = children.firstIndex { node in
            node.pathComponent == first
        }

        if let findIndex {
            children.updateElement(at: findIndex) { node in
                if parts.count == 1 {
                    if node.destination == nil {
                        node.destination = destination
                    } else {
                        assertionFailure("Destination already exists")
                    }
                } else {
                    node.append(parts: Array(parts.dropFirst()), destination: destination)
                }
            }
        } else {
            if parts.count == 1 {
                let newNode = RouterTreeNode(pathComponent: first, destination: destination)
                append(childNode: newNode)
            } else {
                var newNode = RouterTreeNode(pathComponent: first)
                newNode.append(parts: Array(parts.dropFirst()), destination: destination)
                append(childNode: newNode)
            }
        }
    }

    func findDestination(for pathComponents: [String], parameters: [String: Any]) -> DestinationFindResult? {
        guard pathComponents.count > 0 else {
            if let destination {
                return (destination, parameters)
            } else {
                return nil
            }
        }

        var pathComponents = pathComponents
        let first = pathComponents.removeFirst()

        return children.first { node in
            if node.isParameter {
                return true
            } else {
                return node.pathComponent == first
            }
        } using: { node in
            var parameters = parameters
            if node.isParameter {
                parameters[node.parameterName] = first
            }
            if pathComponents.isEmpty {
                if let destination = node.destination {
                    return (destination, parameters)
                } else {
                    return nil
                }
            } else {
                return node.findDestination(for: pathComponents, parameters: parameters)
            }
        } notFound: {
            nil
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
