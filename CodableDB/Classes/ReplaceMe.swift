
public enum SortingOrder {
    public static var `default` = SortingOrder.ascending

    case ascending
    case descending

    var databaseRepresentation: String {
        switch self {
        case .descending:
            return "DESC"
        case .ascending:
            return "ASC"
        }
    }
}

public struct SortDescriptor<O: Object> {
    let databaseRepresentation: String

    public init(codingKeys: [CodingKey], order: SortingOrder) {
        self.databaseRepresentation = codingKeys
            .map { $0.stringValue }
            .joined(separator: ", ")
            + " "
            + order.databaseRepresentation
    }
}

public protocol KeyPathCodable: Codable {
    static func codingKey(for keyPath: PartialKeyPath<Self>) -> CodingKey!
}

extension SortDescriptor where O: KeyPathCodable {
    public static func by(_ keyPaths: PartialKeyPath<O>..., order: SortingOrder = .default) -> SortDescriptor<O> {
        return .init(codingKeys: keyPaths.compactMap(O.codingKey), order: order)
    }

    public static func by<V: ValueType>(_ keyPath: KeyPath<O, V>, order: SortingOrder = .default) -> SortDescriptor<O> {
        return .init(codingKeys: [O.codingKey(for: keyPath)], order: order)
    }
}

extension SortDescriptor: ExpressibleByArrayLiteral where O: KeyPathCodable {
    public typealias ArrayLiteralElement = PartialKeyPath<O>
    public init(arrayLiteral elements: PartialKeyPath<O>...) {
        self.init(codingKeys: elements.compactMap(O.codingKey), order: .default)
    }
}
