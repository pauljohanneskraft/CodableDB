//
//  SQLCommand.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

import SQLite3

func sqlite3_error(_ databasePointer: OpaquePointer!) -> String {
    guard let msgPointer = sqlite3_errmsg(databasePointer) else {
        return "Unknown SQLite3 error"
    }
    return String(cString: msgPointer)
}

protocol SQLCommand {
    associatedtype ReturnType
    var statement: String { get }
    func decode(rowPointer: OpaquePointer, database: Database) throws -> ReturnType
}

extension SQLCommand {
    internal func step(rowPointer: OpaquePointer) throws -> ReturnCode {
        let stepStatus = sqlite3_step(rowPointer)

        guard let returnCode = ReturnCode(rawValue: stepStatus) else {
            throw CodableDBError.unexpectedReturnCode(stepStatus)
        }

        return returnCode
    }
}

struct AnySQLCommand<O: Object, Return>: SQLCommand {
    var statement: String
    private let _decode: (OpaquePointer, String, DatabaseAccessor) throws -> Return

    init(statement: String, _ decode: @escaping (OpaquePointer, String, DatabaseAccessor) throws -> Return) {
        self.statement = statement
        self._decode = decode
    }

    func decode(rowPointer: OpaquePointer, database: Database) throws -> Return {
        return try _decode(rowPointer, statement, database.accessor)
    }
}

struct MultipleRowSQLCommand<O: Object>: SQLCommand {
    let statement: String

    func decodeSingle(rowPointer: OpaquePointer, database: Database) throws -> O {
        let returnCode = try step(rowPointer: rowPointer)

        guard returnCode == .row else {
            throw CodableDBError.noMoreRowAvailable
        }

        return try DatabaseDecoder().decode(O.self, from: rowPointer, database: database)
    }

    func decode(rowPointer: OpaquePointer, database: Database) throws -> [O] {
        var data = [O]()

        do {
            while true {
                data.append(try decodeSingle(rowPointer: rowPointer, database: database))
            }
        } catch let error as CodableDBError
            where error == .noMoreRowAvailable {
            return data
        } catch let error {
            throw error
        }
    }
}

struct NoReturnSQLCommand: SQLCommand {
    let statement: String

    func decode(rowPointer: OpaquePointer, database: Database) throws -> Void {
        let returnCode = try step(rowPointer: rowPointer)

        guard returnCode == .done else {
            throw CodableDBError.errorneousReturnCode(returnCode)
        }
    }
}
