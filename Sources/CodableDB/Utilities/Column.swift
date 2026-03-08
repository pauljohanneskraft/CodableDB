/// A property wrapper that overrides a property's SQL column name.
///
/// Use `@Column("custom_name")` when the SQL column name should differ
/// from the Swift property name. When using ``Model()``, the
/// macro reads the `@Column` attribute automatically:
///
/// ```swift
/// @Model
/// struct User: Object {
///     static var primaryKey: CodingKey { CodingKeys.id }
///
///     var id: String
///     var name: String
///     @Column("email_address") var email: String
///
///     enum CodingKeys: String, CodingKey {
///         case id, name
///         case email = "email_address"
///     }
/// }
/// ```
@propertyWrapper
public struct Column<Value> {
    public var wrappedValue: Value

    /// The custom SQL column name for this property.
    public let name: String

    public init(wrappedValue: Value, _ name: String) {
        self.wrappedValue = wrappedValue
        self.name = name
    }
}

extension Column: Sendable where Value: Sendable {}
extension Column: Equatable where Value: Equatable {
    public static func == (lhs: Column, rhs: Column) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}
extension Column: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        wrappedValue.hash(into: &hasher)
    }
}

extension Column: Encodable where Value: Encodable {
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Column: Decodable where Value: Decodable {
    public init(from decoder: any Decoder) throws {
        self.wrappedValue = try Value(from: decoder)
        self.name = ""
    }
}
