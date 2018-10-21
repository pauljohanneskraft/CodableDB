//
//  Database.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

public protocol DatabaseProtocol {
    func insert<O: Object>(_ object: O) throws
    func delete<O: Object>(_ object: O) throws
    func update<O: Object>(_ object: O) throws
    func getAll<O: Object>(_ object: O.Type, sortedBy: SortDescriptor<O>?, filteredBy: FilterDescriptor<O>?) throws -> [O]
    func count<O: Object>(_: O.Type, filteredBy: FilterDescriptor<O>?) throws -> Int
    func min<O: Object & KeyPathCodable, C: ValueType>(_: O.Type, of keyPath: KeyPath<O, C>, filteredBy filter: FilterDescriptor<O>?) throws -> C?
    func max<O: Object & KeyPathCodable, C: ValueType>(_: O.Type, of keyPath: KeyPath<O, C>, filteredBy filter: FilterDescriptor<O>?) throws -> C?
}

// See https://www.dofactory.com/sql/tutorial
// TODO: Min, Max, Avg, Sum, Like/Wildcards, in/between, Select Top
// TODO: UNIQUE, FOREIGN KEY, CHECK, DEFAULT, INDEX
// TODO: All operators

extension DatabaseProtocol { // TODO: Performance improvements needed
    public func count<O: Object>(_: O.Type, filteredBy filter: FilterDescriptor<O>?) throws -> Int {
        return try getAll(O.self, filteredBy: filter).count // TODO: Performance improvement
    }

    public func min<O: Object & KeyPathCodable, C: ValueType>(_: O.Type, of keyPath: KeyPath<O, C>, filteredBy filter: FilterDescriptor<O>?) throws -> C? {
        return try getAll(O.self, sortedBy: .by(keyPath), filteredBy: filter).first?[keyPath: keyPath]
    }

    public func max<O: Object & KeyPathCodable, C: ValueType>(_: O.Type, of keyPath: KeyPath<O, C>, filteredBy filter: FilterDescriptor<O>?) throws -> C? {
        return try getAll(O.self, sortedBy: .by(keyPath, order: .descending), filteredBy: filter).first?[keyPath: keyPath]
    }
}

extension DatabaseProtocol {
    public func getAll<O: Object>(_ type: O.Type) throws -> [O] {
        return try getAll(O.self, sortedBy: nil, filteredBy: nil)
    }

    public func getAll<O: Object>(_ type: O.Type, sortedBy sorting: SortDescriptor<O>?) throws -> [O] {
        return try getAll(O.self, sortedBy: sorting, filteredBy: nil)
    }

    public func getAll<O: Object>(_ type: O.Type, filteredBy filter: FilterDescriptor<O>?) throws -> [O] {
        return try getAll(O.self, sortedBy: nil, filteredBy: filter)
    }

    public func update<O: Object>(_ object: O) throws {
        try? delete(object)
        try insert(object)
    }

    public func count<O: Object>(_: O.Type) throws -> Int {
        return try count(O.self, filteredBy: nil)
    }
}

public class Database: DatabaseProtocol {
    var accessor: DatabaseAccessor
    let statementFactory = SQLStatementFactory()
    var accessedTables = Set<String>()

    public init(filePath: URL) throws {
        self.accessor = try DatabaseAccessor(filePath: filePath)
        self.accessor.database = self
    }

    public func dropTable<Data: Object>(_: Data.Type) throws {
        let sql = try statementFactory.dropTable(of: Data.self)
        defer { accessedTables.remove(Data.identifier) }
        return try accessor.execute(command: NoReturnSQLCommand(statement: sql))
    }

    public func getAll<Data: Object>(_ type: Data.Type, sortedBy sorting: SortDescriptor<Data>?, filteredBy filter: FilterDescriptor<Data>?) throws -> [Data] {
        let sql = try statementFactory.getAll(Data.self, sortedBy: sorting, filteredBy: filter)
        return try accessor.execute(command: MultipleRowSQLCommand(statement: sql))
    }

    public func insert<Data: Object>(_ object: Data) throws {
        let information = try object.encodingInformation()
        try createTablesIfNeeded(for: information)
        try information
            .values
            .forEach { information in
                let sql = try statementFactory.insert(information)
                try accessor.execute(command: NoReturnSQLCommand(statement: sql))
            }
    }

    public func delete<O: Object>(_ object: O) throws {
        try object
            .encodingInformation()
            .values
            .forEach { type, information in
                guard let primaryKeyValue = information
                    .first(where: { $0.key.stringValue == type.primaryKey.stringValue }) else {
                        throw CodableDBError.unsupportedType
                }
                let sql = try statementFactory.delete(type, primaryKeyValue: primaryKeyValue.value)
                try accessor.execute(command: NoReturnSQLCommand(statement: sql))
            }
    }

    private func isTableAvailable(forIdentifier identifier: String) throws -> Bool {
        let checkSQL = statementFactory.getTables(forIdentifier: identifier)
        do {
            try accessor.execute(command: NoReturnSQLCommand(statement: checkSQL))
        } catch let error as CodableDBError {
            guard case .errorneousReturnCode(.row) = error else {
                throw error
            }
            return true
        }
        return false
    }

    private func getAll<O: Object>(_ type: O.Type, withPrimaryKeyValue value: String) throws -> [O] {
        return try getAll(O.self, filteredBy: .custom(databaseRepresentation: "\(O.primaryKey.stringValue) = \(value)"))
    }

    private func createTablesIfNeeded(for encodingInformation: EncodingInformationStore) throws {
        try encodingInformation
            .filter { try !accessedTables.contains($0.key) || !isTableAvailable(forIdentifier: $0.key) }
            .forEach { key, information in
                try createTable(identifier: key, primaryKey: information.0.primaryKey, encodingInformation: information.1)
                accessedTables.insert(key)
            }
    }

    private func createTable(identifier: String, primaryKey: CodingKey, encodingInformation: [EncodingInformation]) throws {
        let sql = try statementFactory.createTable(identifier: identifier, primaryKey: primaryKey, encodingInformation: encodingInformation)
        return try accessor.execute(command: NoReturnSQLCommand(statement: sql))
    }
}

extension Object {
    fileprivate func encodingInformation() throws -> EncodingInformationStore {
        return try DatabaseEncoder().encodingInformation(for: self)
    }
    fileprivate static func getAll(from database: Database, primaryKeyValue: String) throws -> [Object] {
        return try database.getAll(Self.self, filteredBy: .custom(databaseRepresentation: "\(primaryKey.stringValue) = \(primaryKeyValue)"))
    }
}
