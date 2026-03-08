/// A type that can be persisted in a CodableDB database.
///
/// Conforming types must be `Codable` and provide a table identifier
/// and a primary key used for uniquely identifying rows.
///
/// A default `identifier` is provided using the type name.
///
/// ```swift
/// struct User: Object {
///     static var primaryKey: CodingKey { CodingKeys.id }
///     var id: String
///     var name: String
/// }
/// ```
public protocol Object: Codable {
    /// The table name used in the database. Defaults to the type name.
    static var identifier: String { get }

    /// The coding key used as the primary key for this table.
    static var primaryKey: CodingKey { get }
}

extension Object {
    public static var identifier: String {
        String(describing: self)
    }
}
