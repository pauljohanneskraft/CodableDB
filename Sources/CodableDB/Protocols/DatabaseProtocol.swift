import Foundation
import Sift

/// The public interface for interacting with a CodableDB database.
///
/// Provides CRUD operations on `Object`-conforming types, with optional
/// filtering and sorting powered by Sift predicates and orders.
public protocol DatabaseProtocol {
    /// Inserts an object into the database, creating its table if needed.
    func insert<O: Object>(_ object: O) throws

    /// Deletes an object from the database by its primary key.
    func delete<O: Object>(_ object: O) throws

    /// Updates an object in the database (delete + re-insert).
    func update<O: Object>(_ object: O) throws

    /// Retrieves all objects of the given type, optionally sorted and filtered.
    func getAll<O: Object>(
        _ type: O.Type,
        sortedBy sorting: String?,
        filteredBy filter: String?
    ) throws -> [O]

    /// Returns the count of objects matching an optional filter.
    func count<O: Object>(_ type: O.Type, filteredBy filter: String?) throws -> Int
}

// MARK: - Convenience Overloads

extension DatabaseProtocol {
    public func getAll<O: Object>(_ type: O.Type) throws -> [O] {
        try getAll(type, sortedBy: nil, filteredBy: nil)
    }

    /// Retrieves all objects, sorted and filtered using Sift predicates and orders.
    ///
    /// The predicate and order must conform to `SQLPredicateConvertible` and
    /// `SQLOrderConvertible` respectively, which provide SQL WHERE/ORDER BY clauses.
    public func getAll<O: Object & KeyPathCodable, P: SQLPredicateConvertible, S: SQLOrderConvertible>(
        _ type: O.Type,
        sortedBy sorting: S,
        filteredBy filter: P
    ) throws -> [O] where P.Root == O, S.Root == O {
        try getAll(type, sortedBy: sorting.sqlOrderClause, filteredBy: filter.sqlWhereClause)
    }

    /// Retrieves all objects matching a Sift predicate.
    public func getAll<O: Object & KeyPathCodable, P: SQLPredicateConvertible>(
        _ type: O.Type,
        filteredBy filter: P
    ) throws -> [O] where P.Root == O {
        try getAll(type, sortedBy: nil, filteredBy: filter.sqlWhereClause)
    }

    /// Retrieves all objects sorted by a Sift order.
    public func getAll<O: Object & KeyPathCodable, S: SQLOrderConvertible>(
        _ type: O.Type,
        sortedBy sorting: S
    ) throws -> [O] where S.Root == O {
        try getAll(type, sortedBy: sorting.sqlOrderClause, filteredBy: nil)
    }

    public func update<O: Object>(_ object: O) throws {
        try? delete(object)
        try insert(object)
    }

    public func count<O: Object>(_ type: O.Type) throws -> Int {
        try count(type, filteredBy: nil)
    }

    public func count<O: Object>(_ type: O.Type, filteredBy filter: String?) throws -> Int {
        try getAll(type, sortedBy: nil, filteredBy: filter).count
    }
}
