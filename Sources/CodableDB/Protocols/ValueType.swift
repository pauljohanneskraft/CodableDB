import SQLite3

/// A type that can be encoded into a SQL database representation.
public protocol EncodableValueType: Codable {
    /// The SQL string representation of this value (e.g. `"hello"`, `42`).
    var databaseRepresentation: String { get }

    /// The SQL column type for this value type (e.g. `"BIGINT"`, `"LONGTEXT"`).
    static var databaseType: String { get }
}

extension EncodableValueType {
    /// The SQL column type with a `NOT NULL` constraint.
    static var nonNilDatabaseType: String {
        databaseType + " NOT NULL"
    }
}

/// A type that can be decoded from a SQLite result row.
public protocol DecodableValueType: Codable {
    /// Decodes a value from a SQLite row pointer at the given column index.
    static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Self
}

/// A type that can be both encoded to and decoded from a SQL database.
public protocol ValueType: EncodableValueType, DecodableValueType {}

/// A type that can be round-tripped through a string database representation.
///
/// Used for storing complex types (like arrays) as serialized text in a single column.
public protocol DatabaseRepresentable: EncodableValueType {
    init(databaseRepresentation: String) throws
}
