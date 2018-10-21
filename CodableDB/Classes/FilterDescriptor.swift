//
//  FilterDescriptor.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

public struct FilterDescriptor<O: Object> {
    let databaseRepresentation: String

    public static func custom(databaseRepresentation: String) -> FilterDescriptor<O> {
        return FilterDescriptor(databaseRepresentation: databaseRepresentation)
    }

    public static func and(_ cases: FilterDescriptor<O>...) -> FilterDescriptor<O> {
        return FilterDescriptor(databaseRepresentation:
            "("
            + cases
                .map { $0.databaseRepresentation }
                .joined(separator: " AND ")
            + ")"
        )
    }

    public static func or(_ cases: FilterDescriptor<O>...) -> FilterDescriptor<O> {
        return FilterDescriptor(databaseRepresentation:
            "("
            + cases
                .map { $0.databaseRepresentation }
                .joined(separator: " OR ")
            + ")"
        )
    }

    public static func not(_ descriptor: FilterDescriptor<O>) -> FilterDescriptor<O> {
        return FilterDescriptor(databaseRepresentation: "NOT " + descriptor.databaseRepresentation)
    }

    public static func && (lhs: FilterDescriptor<O>, rhs: FilterDescriptor<O>) -> FilterDescriptor<O> {
        return .and(lhs, rhs)
    }

    public static func || (lhs: FilterDescriptor<O>, rhs: FilterDescriptor<O>) -> FilterDescriptor<O> {
        return .or(lhs, rhs)
    }

    public static prefix func !(lhs: FilterDescriptor) -> FilterDescriptor {
        return .not(lhs)
    }
}

extension FilterDescriptor where O: KeyPathCodable {
    public static func isNull<V: ValueType>(_ keyPath: KeyPath<O, V?>) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) IS NULL")
    }

    public static func isNotNull<V: ValueType>(_ keyPath: KeyPath<O, V?>) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) IS NOT NULL")
    }

    public static func equals<V: ValueType & Equatable>(_ keyPath: KeyPath<O, V>, to value: V) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) = \(value.databaseRepresentation)")
    }

    public static func less<V: ValueType & Comparable>(_ keyPath: KeyPath<O, V>, than value: V) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) < \(value.databaseRepresentation)")
    }

    public static func greater<V: ValueType & Comparable>(_ keyPath: KeyPath<O, V>, than value: V) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) > \(value.databaseRepresentation)")
    }

    public static func notEquals<V: ValueType & Equatable>(_ keyPath: KeyPath<O, V?>, to value: V?) -> FilterDescriptor {
        if let v = value {
            return .not(.equals(keyPath, to: v))
        } else {
            return .isNotNull(keyPath)
        }
    }

    public static func equals<V: ValueType & Equatable>(_ keyPath: KeyPath<O, V?>, to value: V?) -> FilterDescriptor {
        if let v = value {
            let key = O.codingKey(for: keyPath).stringValue
            return FilterDescriptor(databaseRepresentation: "\(key) = \(v.databaseRepresentation)")
        } else {
            return .isNull(keyPath)
        }
    }

    public static func less<V: ValueType & Comparable>(_ keyPath: KeyPath<O, V?>, than value: V) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) < \(value.databaseRepresentation)")
    }

    public static func greater<V: ValueType & Comparable>(_ keyPath: KeyPath<O, V?>, than value: V) -> FilterDescriptor {
        let key = O.codingKey(for: keyPath).stringValue
        return FilterDescriptor(databaseRepresentation: "\(key) > \(value.databaseRepresentation)")
    }
}

public func == <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: KeyPath<O, V>, rhs: V) -> FilterDescriptor<O> {
    return .equals(lhs, to: rhs)
}

public func == <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: V, rhs: KeyPath<O, V>) -> FilterDescriptor<O> {
    return .equals(rhs, to: lhs)
}

public func != <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: KeyPath<O, V>, rhs: V) -> FilterDescriptor<O> {
    return .not(.equals(lhs, to: rhs))
}

public func != <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: V, rhs: KeyPath<O, V>) -> FilterDescriptor<O> {
    return .not(.equals(rhs, to: lhs))
}

public func < <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: KeyPath<O, V>, rhs: V) -> FilterDescriptor<O> {
    return .less(lhs, than: rhs)
}

public func < <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: V, rhs: KeyPath<O, V>) -> FilterDescriptor<O> {
    return .greater(rhs, than: lhs)
}

public func > <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: KeyPath<O, V>, rhs: V) -> FilterDescriptor<O> {
    return .greater(lhs, than: rhs)
}

public func > <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: V, rhs: KeyPath<O, V>) -> FilterDescriptor<O> {
    return .less(rhs, than: lhs)
}

public func != <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: KeyPath<O, V?>, rhs: V?) -> FilterDescriptor<O> {
    return .notEquals(lhs, to: rhs)
}

public func != <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: V?, rhs: KeyPath<O, V?>) -> FilterDescriptor<O> {
    return .notEquals(rhs, to: lhs)
}

public func == <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: KeyPath<O, V?>, rhs: V?) -> FilterDescriptor<O> {
    return .equals(lhs, to: rhs)
}

public func == <O: Object & KeyPathCodable, V: ValueType & Equatable>(lhs: V?, rhs: KeyPath<O, V?>) -> FilterDescriptor<O> {
    return .equals(rhs, to: lhs)
}

public func < <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: KeyPath<O, V?>, rhs: V) -> FilterDescriptor<O> {
    return .less(lhs, than: rhs)
}

public func < <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: V, rhs: KeyPath<O, V?>) -> FilterDescriptor<O> {
    return .greater(rhs, than: lhs)
}

public func > <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: KeyPath<O, V?>, rhs: V) -> FilterDescriptor<O> {
    return .greater(lhs, than: rhs)
}

public func > <O: Object & KeyPathCodable, V: ValueType & Comparable>(lhs: V, rhs: KeyPath<O, V?>) -> FilterDescriptor<O> {
    return .less(rhs, than: lhs)
}
