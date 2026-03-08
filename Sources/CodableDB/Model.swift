/// Automatically generates `KeyPathCodable` conformance for an `Object` type.
///
/// Attach this macro to a struct that conforms to `Object`. It inspects
/// all stored `var` properties and synthesizes a `columns` dictionary
/// mapping each key path to its SQL column name.
///
/// If a property uses `@Column("custom_name")`, the custom name is used.
/// Otherwise the property name is used as the column name.
///
/// ```swift
/// @Model
/// struct Task: Object {
///     static var primaryKey: CodingKey { CodingKeys.id }
///
///     var id: String
///     var title: String
///     var priority: Int
///     @Column("is_done") var isCompleted: Bool
/// }
/// ```
///
/// This generates:
/// ```swift
/// extension Task: KeyPathCodable {
///     static var columns: [PartialKeyPath<Task>: String] {
///         [\.id: "id", \.title: "title", \.priority: "priority", \.isCompleted: "is_done"]
///     }
/// }
/// ```
@attached(member, names: named(columns))
@attached(extension, conformances: KeyPathCodable)
public macro Model() =
    #externalMacro(module: "CodableDBMacros", type: "CodableDBModelMacro")
