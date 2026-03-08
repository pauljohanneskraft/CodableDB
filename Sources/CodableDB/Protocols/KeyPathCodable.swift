/// A type whose properties can be referenced by key path in SQL queries.
///
/// By default, the SQL column name for a key path is the Swift property name.
/// Override ``columnOverrides`` to provide custom column names for properties
/// annotated with ``Column``.
///
/// ```swift
/// struct User: Object, KeyPathCodable {
///     static var primaryKey: CodingKey { CodingKeys.id }
///
///     var id: String
///     var name: String  // column = "name"
///     @Column("email_address") var email: String
///
///     enum CodingKeys: String, CodingKey {
///         case id, name
///         case email = "email_address"
///     }
///     static var columnOverrides: [PartialKeyPath<User>: String] {
///         [\.email: "email_address"]
///     }
/// }
/// ```
public protocol KeyPathCodable: Codable {
    /// A dictionary mapping key paths to custom SQL column names.
    ///
    /// Only override this when using ``Column`` to rename properties.
    /// Properties not listed here use their Swift property name.
    static var columnOverrides: [PartialKeyPath<Self>: String] { get }
}

extension KeyPathCodable {
    public static var columnOverrides: [PartialKeyPath<Self>: String] { [:] }

    /// Resolves the SQL column name for the given key path.
    ///
    /// Checks ``columnOverrides`` first, then falls back to the
    /// key path's underlying property name.
    static func columnName(for keyPath: PartialKeyPath<Self>) -> String? {
        if let override = columnOverrides[keyPath] {
            return override
        }
        return keyPath._kvcKeyPathString
    }
}
