/// A type whose properties can be referenced by key path in SQL queries.
///
/// Rather than implementing this protocol manually, use the ``Model()``
/// macro which auto-generates the ``columns`` dictionary from your stored properties:
///
/// ```swift
/// @Model
/// struct User {
///     static var primaryKey: CodingKey { CodingKeys.id }
///
///     var id: String
///     var name: String
///     @Column("email_address") var email: String
/// }
/// ```
///
/// For manual conformance, provide a ``columns`` dictionary mapping every
/// stored key path to its SQL column name.
public protocol KeyPathCodable: Codable {
    /// A dictionary mapping **every** stored key path to its SQL column name.
    ///
    /// This is the source of truth for key-path → column resolution used
    /// by Sift predicates and orderings.
    ///
    /// ```swift
    /// static var columns: [PartialKeyPath<Self>: String] {
    ///     [\.id: "id", \.name: "name", \.score: "score"]
    /// }
    /// ```
    static var columns: [PartialKeyPath<Self>: String] { get }
}

extension KeyPathCodable {
    /// Resolves the SQL column name for the given key path.
    static func columnName(for keyPath: PartialKeyPath<Self>) -> String? {
        columns[keyPath]
    }
}
