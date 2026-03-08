import SQLite3

/// A SQL statement that can decode a result from a SQLite row pointer.
protocol SQLCommand {
    associatedtype ReturnType
    var statement: String { get }
    func decode(rowPointer: OpaquePointer, database: Database) throws -> ReturnType
}

extension SQLCommand {
    func step(rowPointer: OpaquePointer) throws -> ReturnCode {
        let stepStatus = sqlite3_step(rowPointer)
        guard let returnCode = ReturnCode(rawValue: stepStatus) else {
            throw CodableDBError.unexpectedReturnCode(stepStatus)
        }
        return returnCode
    }
}

/// A SQL command that returns multiple decoded rows.
struct MultipleRowSQLCommand<O: Object>: SQLCommand {
    let statement: String

    func decode(rowPointer: OpaquePointer, database: Database) throws -> [O] {
        var data = [O]()
        while true {
            let returnCode = try step(rowPointer: rowPointer)
            guard returnCode == .row else { break }
            data.append(try DatabaseDecoder().decode(O.self, from: rowPointer, database: database))
        }
        return data
    }
}

/// A SQL command that returns no data (INSERT, CREATE, DELETE, etc.).
struct NoReturnSQLCommand: SQLCommand {
    let statement: String

    func decode(rowPointer: OpaquePointer, database: Database) throws {
        let returnCode = try step(rowPointer: rowPointer)
        guard returnCode == .done else {
            throw CodableDBError.erroneousReturnCode(returnCode)
        }
    }
}
