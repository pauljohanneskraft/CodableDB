import Sift

/// A Sift predicate that can produce a SQL WHERE clause.
///
/// Conforming types bridge between Sift's type-safe predicate DSL
/// and CodableDB's SQL generation, enabling expressions like:
///
/// ```swift
/// db.getAll(User.self, filteredBy: \.age > 18 && \.name == "Alice")
/// ```
public protocol SQLPredicateConvertible: Predicate where Root: KeyPathCodable {
    /// The SQL WHERE clause fragment for this predicate (e.g. `"age > 18"`).
    var sqlWhereClause: String { get }
}

// MARK: - Value Predicates (KeyPath op Value)

/// Maps a Sift `PredicateValueOperator` to a SQL comparison operator string.
public protocol SQLPredicateValueOperator: PredicateValueOperator where Value: ValueType {
    /// The SQL operator (e.g. `"="`, `"<"`, `">"`).
    static var sqlOperator: String { get }
}

extension EqualOperator: SQLPredicateValueOperator where Value: ValueType & Equatable {
    public static var sqlOperator: String { "=" }
}

extension NotEqualOperator: SQLPredicateValueOperator where Value: ValueType & Equatable {
    public static var sqlOperator: String { "!=" }
}

extension LessThanOperator: SQLPredicateValueOperator where Value: ValueType & Comparable {
    public static var sqlOperator: String { "<" }
}

extension LessThanOrEqualOperator: SQLPredicateValueOperator where Value: ValueType & Comparable {
    public static var sqlOperator: String { "<=" }
}

extension GreaterThanOperator: SQLPredicateValueOperator where Value: ValueType & Comparable {
    public static var sqlOperator: String { ">" }
}

extension GreaterThanOrEqualOperator: SQLPredicateValueOperator
where Value: ValueType & Comparable {
    public static var sqlOperator: String { ">=" }
}

extension KeyPathValuePredicateValue: SQLPredicateConvertible
where Root: KeyPathCodable, Operator: SQLPredicateValueOperator, Operator.Value: ValueType {
    public var sqlWhereClause: String {
        guard let name = Root.columnName(for: keyPath) else {
            return "1 = 1"
        }
        return "\(name) \(Operator.sqlOperator) \(value.databaseRepresentation)"
    }
}

extension KeyPathKeyPathPredicateValue: SQLPredicateConvertible
where Root: KeyPathCodable, Operator: SQLPredicateValueOperator {
    public var sqlWhereClause: String {
        guard let name0 = Root.columnName(for: keyPaths.0),
            let name1 = Root.columnName(for: keyPaths.1)
        else {
            return "1 = 1"
        }
        return "\(name0) \(Operator.sqlOperator) \(name1)"
    }
}

// MARK: - Binary Predicates (AND, OR)

/// Maps a Sift binary predicate operator to a SQL logical operator.
public protocol SQLBinaryPredicateOperator {
    static var sqlOperator: String { get }
}

extension AndOperator: SQLBinaryPredicateOperator {
    public static var sqlOperator: String { "AND" }
}

extension OrOperator: SQLBinaryPredicateOperator {
    public static var sqlOperator: String { "OR" }
}

extension BinaryPredicate: SQLPredicateConvertible
where
    First: SQLPredicateConvertible, Second: SQLPredicateConvertible,
    Operator: SQLBinaryPredicateOperator, First.Root: KeyPathCodable
{
    public var sqlWhereClause: String {
        "(\(elements.first.sqlWhereClause) \(Operator.sqlOperator) \(elements.second.sqlWhereClause))"
    }
}

// MARK: - Unary Predicates (NOT)

extension UnaryPredicate: SQLPredicateConvertible
where Content: SQLPredicateConvertible, Operator == NotOperator, Content.Root: KeyPathCodable {
    public var sqlWhereClause: String {
        "NOT \(content.sqlWhereClause)"
    }
}

// MARK: - Boolean Predicates

extension BooleanPredicate: SQLPredicateConvertible where Root: KeyPathCodable {
    public var sqlWhereClause: String {
        value ? "1 = 1" : "1 = 0"
    }
}
