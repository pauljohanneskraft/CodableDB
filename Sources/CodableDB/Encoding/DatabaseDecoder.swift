import SQLite3

/// Decodes `Object` types from SQLite result row pointers.
class DatabaseDecoder {
    func decode<O: Object>(_ type: O.Type, from resultPointer: OpaquePointer, database: Database) throws -> O {
        let decoder = DatabaseObjectDecoder<O>(pointer: resultPointer, database: database)
        return try O(from: decoder)
    }
}

// MARK: - Decoder

private class DatabaseObjectDecoder<O: Object>: Decoder {
    let pointer: OpaquePointer
    let database: Database

    init(pointer: OpaquePointer, database: Database) {
        self.pointer = pointer
        self.database = database
    }

    var codingPath: [CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(DatabaseKeyedDecodingContainer<O, Key>(pointer: pointer, database: database))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer { throw CodableDBError.unsupportedType }
    func singleValueContainer() throws -> SingleValueDecodingContainer { throw CodableDBError.unsupportedType }
}

// MARK: - Keyed Decoding Container

private class DatabaseKeyedDecodingContainer<O: Object, Key: CodingKey> {
    let pointer: OpaquePointer
    let database: Database
    var index: Int32 = 0
    var codingPath = [CodingKey]()
    var allKeys = [Key]()

    init(pointer: OpaquePointer, database: Database) {
        self.pointer = pointer
        self.database = database
    }
}

extension DatabaseKeyedDecodingContainer: KeyedDecodingContainerProtocol {
    func contains(_ key: Key) -> Bool {
        codingPath.contains { $0.stringValue == key.stringValue }
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        sqlite3_column_type(pointer, index) == SQLITE_NULL
    }

    // MARK: Optional Primitives

    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? { try decodeOptionalValueType(type, forKey: key) }
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? { try decodeOptionalValueType(type, forKey: key) }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        switch type {
        case let v as any ValueType.Type:
            return try decodeGenericOptionalValueType(v, forKey: key) as? T
        case let o as any Object.Type:
            return try decodeGenericOptionalObject(o, forKey: key) as? T
        default:
            throw CodableDBError.unsupportedType
        }
    }

    // MARK: Required Primitives

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try decodeValueType(type, forKey: key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try decodeValueType(type, forKey: key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try decodeValueType(type, forKey: key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try decodeValueType(type, forKey: key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try decodeValueType(type, forKey: key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try decodeValueType(type, forKey: key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try decodeValueType(type, forKey: key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try decodeValueType(type, forKey: key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try decodeValueType(type, forKey: key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try decodeValueType(type, forKey: key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try decodeValueType(type, forKey: key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try decodeValueType(type, forKey: key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try decodeValueType(type, forKey: key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try decodeValueType(type, forKey: key) }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        switch T.self {
        case let t as any ValueType.Type:
            guard let valueType = try decodeGenericValueType(t, forKey: key) as? T else {
                throw CodableDBError.unsupportedType
            }
            return valueType
        case let o as any Object.Type:
            guard let object = try decodeGenericObject(o, forKey: key) as? T else {
                throw CodableDBError.unsupportedType
            }
            return object
        default:
            throw CodableDBError.unsupportedType
        }
    }

    // MARK: Value Type Decoding

    private func decodeGenericValueType(_ type: any ValueType.Type, forKey key: Key) throws -> any ValueType {
        defer { index += 1 }
        return try type.decode(rowPointer: pointer, index: index)
    }

    private func decodeValueType<V: ValueType>(_ type: V.Type, forKey key: Key) throws -> V {
        try decodeGenericValueType(type, forKey: key) as! V
    }

    private func decodeGenericOptionalValueType(_ type: any ValueType.Type, forKey key: Key) throws -> (any ValueType)? {
        guard try !decodeNil(forKey: key) else { return nil }
        return try decodeGenericValueType(type, forKey: key)
    }

    private func decodeOptionalValueType<V: ValueType>(_ type: V.Type, forKey key: Key) throws -> V? {
        try decodeGenericOptionalValueType(type, forKey: key) as? V
    }

    // MARK: Object Decoding

    private func decodeGenericOptionalObject(_ type: any Object.Type, forKey key: Key) throws -> (any Object)? {
        guard sqlite3_column_type(pointer, index) != SQLITE_NULL else {
            index += 1
            return nil
        }
        return try decodeGenericObject(type, forKey: key)
    }

    private func decodeGenericObject(_ type: any Object.Type, forKey key: Key) throws -> any Object {
        defer { index += 1 }
        let value: any ValueType
        switch sqlite3_column_type(pointer, index) {
        case SQLITE_INTEGER:
            value = try decode(Int64.self, forKey: key)
        case SQLITE_TEXT:
            value = try decode(String.self, forKey: key)
        case SQLITE_FLOAT:
            value = try decode(Double.self, forKey: key)
        default:
            throw CodableDBError.unsupportedType
        }
        let primaryKeyClause = "\(type.primaryKey.stringValue) = \(value.databaseRepresentation)"
        guard let object = try database.getAll(type, sortedBy: nil, filteredBy: primaryKeyClause).first else {
            throw CodableDBError.inconsistentData(description: "Could not find value for key \(key) in database.")
        }
        return object
    }

    // MARK: Unsupported

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> { throw CodableDBError.unsupportedType }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { throw CodableDBError.unsupportedType }
    func superDecoder() throws -> Decoder { throw CodableDBError.unsupportedType }
    func superDecoder(forKey key: Key) throws -> Decoder { throw CodableDBError.unsupportedType }
}

// MARK: - Object Primary Key Lookup

extension Database {
    /// Fetches objects of any `Object` type by primary key clause (used by decoder).
    func getAll(_ type: any Object.Type, sortedBy: String?, filteredBy: String?) throws -> [any Object] {
        // This needs to dispatch dynamically since we don't have the concrete type at compile time.
        // We use the generic version via a helper.
        try _getAllDynamic(type, sortedBy: sortedBy, filteredBy: filteredBy)
    }

    private func _getAllDynamic(_ type: any Object.Type, sortedBy: String?, filteredBy: String?) throws -> [any Object] {
        func helper<O: Object>(_ type: O.Type) throws -> [any Object] {
            let sql = statementFactory.getAll(O.self, sortedBy: sortedBy, filteredBy: filteredBy)
            let results: [O] = try accessor.execute(command: MultipleRowSQLCommand(statement: sql))
            return results
        }
        return try _openExistential(type, do: helper)
    }
}
