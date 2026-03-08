import Foundation

/// Errors that can occur during CodableDB operations.
public enum CodableDBError: Error, Equatable, Sendable {
    /// The query returned no more rows (internal sentinel).
    case noMoreRowAvailable
    /// SQLite statement preparation failed.
    case preparationFailed(sqliteError: String)
    /// The database file could not be opened at the given path.
    case couldNotFindDatabase(atPath: URL)
    /// The return value did not match what was expected for the command.
    case incorrectReturnForCommand
    /// The type is not supported for encoding/decoding.
    case unsupportedType
    /// SQLite returned an unexpected result code.
    case unexpectedReturnCode(Int32)
    /// SQLite returned an erroneous result code.
    case erroneousReturnCode(ReturnCode)
    /// The database contains inconsistent data.
    case inconsistentData(description: String)
}
