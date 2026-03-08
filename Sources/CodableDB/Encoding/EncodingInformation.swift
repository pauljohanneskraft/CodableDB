/// A single column's encoding information: its coding key, SQL type, and value.
struct ColumnEncoding {
    let key: CodingKey
    let type: String
    let value: String
}

/// Information about an object type and its encoded columns.
struct TableEncoding {
    let type: Object.Type
    let columns: [ColumnEncoding]
}

/// Maps table identifiers to their encoding information.
typealias EncodingInformationStore = [String: TableEncoding]
