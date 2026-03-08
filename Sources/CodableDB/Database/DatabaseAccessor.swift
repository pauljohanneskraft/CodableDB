import Foundation
import SQLite3

/// Manages the low-level SQLite connection and statement execution.
class DatabaseAccessor {
    private var databasePointer: OpaquePointer
    weak var database: Database!

    init(filePath: URL) throws {
        var pointer: OpaquePointer?
        let status = sqlite3_open(filePath.absoluteString, &pointer)

        guard status == SQLITE_OK, let databasePointer = pointer else {
            throw CodableDBError.couldNotFindDatabase(atPath: filePath)
        }

        self.databasePointer = databasePointer
    }

    @discardableResult
    func execute<Command: SQLCommand>(command: Command) throws -> Command.ReturnType {
        let rowPointer = try prepare(statement: command.statement)
        log(#function, command.statement)
        defer { sqlite3_finalize(rowPointer) }
        return try command.decode(rowPointer: rowPointer, database: database)
    }

    private func prepare(statement: String) throws -> OpaquePointer {
        var rowPointer: OpaquePointer?
        let preparationStatus = sqlite3_prepare_v2(databasePointer, statement, -1, &rowPointer, nil)

        guard preparationStatus == SQLITE_OK, let result = rowPointer else {
            throw CodableDBError.preparationFailed(sqliteError: sqlite3Error(databasePointer))
        }

        return result
    }
}

/// Extracts the current error message from a SQLite database pointer.
func sqlite3Error(_ databasePointer: OpaquePointer!) -> String {
    guard let msgPointer = sqlite3_errmsg(databasePointer) else {
        return "Unknown SQLite3 error"
    }
    return String(cString: msgPointer)
}
