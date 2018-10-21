//
//  SQLStatementFactory.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

class SQLStatementFactory {
    func createTable(identifier: String, primaryKey: CodingKey, encodingInformation: [EncodingInformation]) throws -> String {
        let body = encodingInformation
            .map { key, type, _ -> String in
                return key.stringValue + " " + type
            }
            .joined(separator: ", ")
            + ", PRIMARY KEY ("
            + primaryKey.stringValue
            + ")"

        return "CREATE TABLE \(identifier)(\(body));"
    }

    func dropTable(of type: Object.Type) throws -> String {
        return "DROP TABLE \(type.identifier);"
    }

    func insert(_ information: (Object.Type, [EncodingInformation])) throws -> String {
        let types = information.1.map { $0.key.stringValue }.joined(separator: ", ")
        let values = information.1
            .map { key, type, value in value }
            .joined(separator: ", ")
        return "INSERT INTO \(information.0.identifier) (\(types)) VALUES (\(values));"
    }

    func getAllGeneric(_ type: Object.Type, sortedBy sorting: String? = nil, filteredBy filter: String? = nil) throws -> String {
        var command = "SELECT * FROM \(type.identifier)"
        if let filter = filter {
            command += " WHERE " + filter
        }
        if let sort = sorting {
            command += " ORDER BY " + sort
        }
        return command + ";"
    }

    func getAll<O: Object>(_: O.Type, sortedBy sorting: SortDescriptor<O>? = nil, filteredBy filter: FilterDescriptor<O>? = nil) throws -> String {
        var command = "SELECT * FROM \(O.identifier)"
        if let filter = filter {
            command += " WHERE " + filter.databaseRepresentation
        }
        if let sort = sorting {
            command += " ORDER BY " + sort.databaseRepresentation
        }
        return command + ";"
    }

    func update<O: Object>(_ object: O) throws -> String {
        let information = try DatabaseEncoder().encode(object)

        let body = information
            .map { key, type, value in
                "\(key.stringValue) = \(value)"
            }
            .joined(separator: ", ")
        guard let primaryKeyValue = information
            .first(where: { $0.key.stringValue == O.primaryKey.stringValue })?
            .value else {
                log("primary key needs to be set.")
                throw CodableDBError.unsupportedType
        }
        return "UPDATE \(O.identifier) SET \(body) WHERE \(O.primaryKey.stringValue) = \(primaryKeyValue);"
    }

    func delete(_ type: Object.Type, primaryKeyValue: String) throws -> String {
        return "DELETE FROM \(type.identifier) WHERE \(type.primaryKey.stringValue) = \(primaryKeyValue);"
    }

    func getTables(forIdentifier identifier: String) -> String {
        return "SELECT name FROM sqlite_master WHERE type='table' AND name='\(identifier)';"
    }
}
