import Sift

/// A Sift order that can produce a SQL ORDER BY clause.
///
/// Conforming types bridge between Sift's type-safe order DSL
/// and CodableDB's SQL generation, enabling expressions like:
///
/// ```swift
/// db.getAll(User.self, sortedBy: Ascending(\.name))
/// ```
public protocol SQLOrderConvertible: Order where Root: KeyPathCodable {
    /// The SQL ORDER BY clause fragment (e.g. `"name ASC"`).
    var sqlOrderClause: String { get }
}

// MARK: - KeyPath Orders

extension KeyPath: SQLOrderConvertible where Root: KeyPathCodable {
    public var sqlOrderClause: String {
        guard let name = Root.columnName(for: self) else { return "" }
        return "\(name) ASC"
    }
}

extension Ascending: SQLOrderConvertible where Operator: SQLOrderConvertible, Root: KeyPathCodable {
    public var sqlOrderClause: String {
        // Replace the trailing direction with ASC
        let base = self.operator.sqlOrderClause
        return replaceDirection(in: base, with: "ASC")
    }
}

extension Descending: SQLOrderConvertible
where Operator: SQLOrderConvertible, Root: KeyPathCodable {
    public var sqlOrderClause: String {
        let base = self.operator.sqlOrderClause
        return replaceDirection(in: base, with: "DESC")
    }
}

extension Reverse: SQLOrderConvertible where O: SQLOrderConvertible, Root: KeyPathCodable {
    public var sqlOrderClause: String {
        let base = order.sqlOrderClause
        // Flip ASC ↔ DESC for each component
        return
            base
            .components(separatedBy: ", ")
            .map { component in
                if component.hasSuffix("ASC") {
                    return component.replacingOccurrences(of: "ASC", with: "DESC")
                } else if component.hasSuffix("DESC") {
                    return component.replacingOccurrences(of: "DESC", with: "ASC")
                }
                return component
            }
            .joined(separator: ", ")
    }
}

extension ConcatenatedOrder: SQLOrderConvertible
where First: SQLOrderConvertible, Second: SQLOrderConvertible, Root: KeyPathCodable {
    public var sqlOrderClause: String {
        "\(first.sqlOrderClause), \(second.sqlOrderClause)"
    }
}

// MARK: - Helpers

private func replaceDirection(in clause: String, with direction: String) -> String {
    clause
        .components(separatedBy: ", ")
        .map { component in
            // Strip existing direction and append desired one
            var trimmed = component
            for suffix in [" ASC", " DESC"] {
                if trimmed.hasSuffix(suffix) {
                    trimmed = String(trimmed.dropLast(suffix.count))
                    break
                }
            }
            return "\(trimmed) \(direction)"
        }
        .joined(separator: ", ")
}
