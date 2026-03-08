import SQLite3

private let databaseRepresentationSeparator: Character = ","

extension Array: EncodableValueType, DecodableValueType, ValueType
where Element: DatabaseRepresentable {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> [Element] {
        try String
            .decode(rowPointer: rowPointer, index: index)
            .split(separator: databaseRepresentationSeparator)
            .map { try Element(databaseRepresentation: String($0)) }
    }

    public static var databaseType: String { "LONGTEXT" }

    public var databaseRepresentation: String {
        map { $0.databaseRepresentation }
            .joined(separator: String(databaseRepresentationSeparator))
    }
}
