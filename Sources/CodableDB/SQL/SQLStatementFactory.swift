/// Generates SQL statement strings for database operations.
struct SQLStatementFactory {

    func createTable(identifier: String, primaryKey: CodingKey, columns: [ColumnEncoding]) -> String
    {
        let body =
            columns
            .map { "\($0.key.stringValue) \($0.type)" }
            .joined(separator: ", ")
            + ", PRIMARY KEY (\(primaryKey.stringValue))"
        return "CREATE TABLE \(identifier)(\(body));"
    }

    func dropTable(of type: any Object.Type) -> String {
        "DROP TABLE \(type.identifier);"
    }

    func insert(_ information: (type: any Object.Type, columns: [ColumnEncoding])) throws -> String
    {
        let columnNames = information.columns.map { $0.key.stringValue }.joined(separator: ", ")
        let values = information.columns.map { $0.value }.joined(separator: ", ")
        return "INSERT INTO \(information.type.identifier) (\(columnNames)) VALUES (\(values));"
    }

    func getAll<O: Object>(
        _: O.Type, sortedBy sorting: String? = nil, filteredBy filter: String? = nil
    ) -> String {
        var command = "SELECT * FROM \(O.identifier)"
        if let filter {
            command += " WHERE " + filter
        }
        if let sort = sorting {
            command += " ORDER BY " + sort
        }
        return command + ";"
    }

    func delete(_ type: any Object.Type, primaryKeyValue: String) -> String {
        "DELETE FROM \(type.identifier) WHERE \(type.primaryKey.stringValue) = \(primaryKeyValue);"
    }

    func getTables(forIdentifier identifier: String) -> String {
        "SELECT name FROM sqlite_master WHERE type='table' AND name='\(identifier)';"
    }
}
