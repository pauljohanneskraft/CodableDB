import Foundation

/// A SQLite-backed database that stores `Object`-conforming types.
///
/// Tables are created automatically on first insert. The database uses
/// Swift's `Codable` system to map between objects and SQL rows.
///
/// ```swift
/// let db = try Database(filePath: url)
/// try db.insert(user)
/// let users: [User] = try db.getAll(User.self, filteredBy: \.age > 18)
/// ```
public class Database: DatabaseProtocol {
    var accessor: DatabaseAccessor
    let statementFactory = SQLStatementFactory()
    var accessedTables = Set<String>()

    /// Opens or creates a SQLite database at the given file URL.
    public init(filePath: URL) throws {
        self.accessor = try DatabaseAccessor(filePath: filePath)
        self.accessor.database = self
    }

    /// Drops the table for the given object type.
    public func dropTable<O: Object>(_: O.Type) throws {
        let sql = statementFactory.dropTable(of: O.self)
        defer { accessedTables.remove(O.identifier) }
        try accessor.execute(command: NoReturnSQLCommand(statement: sql))
    }

    public func getAll<O: Object>(
        _ type: O.Type,
        sortedBy sorting: String?,
        filteredBy filter: String?
    ) throws -> [O] {
        let sql = statementFactory.getAll(O.self, sortedBy: sorting, filteredBy: filter)
        return try accessor.execute(command: MultipleRowSQLCommand(statement: sql))
    }

    public func insert<O: Object>(_ object: O) throws {
        let information = try DatabaseEncoder().encodingInformation(for: object)
        try createTablesIfNeeded(for: information)
        for info in information.values {
            let sql = try statementFactory.insert((info.type, info.columns))
            try accessor.execute(command: NoReturnSQLCommand(statement: sql))
        }
    }

    public func delete<O: Object>(_ object: O) throws {
        let information = try DatabaseEncoder().encodingInformation(for: object)
        for info in information.values {
            guard
                let primaryKeyValue = info.columns
                    .first(where: { $0.key.stringValue == info.type.primaryKey.stringValue })
            else {
                throw CodableDBError.unsupportedType
            }
            let sql = statementFactory.delete(info.type, primaryKeyValue: primaryKeyValue.value)
            try accessor.execute(command: NoReturnSQLCommand(statement: sql))
        }
    }

    // MARK: - Private

    private func isTableAvailable(forIdentifier identifier: String) throws -> Bool {
        let checkSQL = statementFactory.getTables(forIdentifier: identifier)
        do {
            try accessor.execute(command: NoReturnSQLCommand(statement: checkSQL))
        } catch let error as CodableDBError {
            guard case .erroneousReturnCode(.row) = error else {
                throw error
            }
            return true
        }
        return false
    }

    private func createTablesIfNeeded(for store: EncodingInformationStore) throws {
        for (key, info) in store {
            var needsCreation = true
            if accessedTables.contains(key) {
                needsCreation = try !isTableAvailable(forIdentifier: key)
            }
            if needsCreation {
                try createTable(
                    identifier: key,
                    primaryKey: info.type.primaryKey,
                    columns: info.columns
                )
                accessedTables.insert(key)
            }
        }
    }

    private func createTable(
        identifier: String,
        primaryKey: CodingKey,
        columns: [ColumnEncoding]
    ) throws {
        let sql = statementFactory.createTable(
            identifier: identifier,
            primaryKey: primaryKey,
            columns: columns
        )
        try accessor.execute(command: NoReturnSQLCommand(statement: sql))
    }
}
