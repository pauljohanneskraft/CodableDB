//
//  DatabaseAccessor.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

import SQLite3
import Dispatch

class DatabaseAccessor {
    private var databasePointer: OpaquePointer
    internal weak var database: Database!

    internal init(filePath: URL) throws {
        var pointer: OpaquePointer?
        let status = sqlite3_open(filePath.absoluteString, &pointer)

        guard status == SQLITE_OK,
            let databasePointer = pointer else {
                throw CodableDBError.couldNotFindDatabase(atPath: filePath)
        }

        self.databasePointer = databasePointer
    }

    internal func execute<Command: SQLCommand>(command: Command) throws -> Command.ReturnType {
        let rowPointer = try prepare(statement: command.statement)
        log(#function, command.statement)
        defer { sqlite3_finalize(rowPointer) }
        return try command.decode(rowPointer: rowPointer, database: database)
    }

    private func prepare(statement: String) throws -> OpaquePointer {
        var rowPointer: OpaquePointer?
        let preparationStatus = sqlite3_prepare_v2(databasePointer, statement, -1, &rowPointer, nil)

        guard preparationStatus == SQLITE_OK,
            let result = rowPointer else {
                throw CodableDBError.preparationFailed(sqliteError: sqlite3_error(databasePointer))
        }

        return result

    }
}
