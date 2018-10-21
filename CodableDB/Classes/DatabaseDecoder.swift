//
//  DatabaseDecoder.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

import SQLite3

class DatabaseDecoder {
    func decode<Data: Object>(_ type: Data.Type, from resultPointer: OpaquePointer, database: Database) throws -> Data {
        let decoder = DatabaseObjectDecoder<Data>(pointer: resultPointer, database: database)
        return try Data(from: decoder)
    }
}

class DatabaseObjectDecoder<Data: Object>: Decoder {

    let pointer: OpaquePointer
    let database: Database

    init(pointer: OpaquePointer, database: Database) {
        self.pointer = pointer
        self.database = database
    }

    var codingPath: [CodingKey] { return [] }

    var userInfo: [CodingUserInfoKey : Any] { return [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let container = DatabaseKeyedContainer<Data, Key>(pointer: pointer, database: database)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw CodableDBError.unsupportedType
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw CodableDBError.unsupportedType
    }
}

class DatabaseKeyedContainer<Data: Object, Key: CodingKey> {
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

extension DatabaseKeyedContainer: KeyedDecodingContainerProtocol {
    func contains(_ key: Key) -> Bool {
        return codingPath.contains { $0.stringValue == key.stringValue }
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        return sqlite3_column_type(pointer, index) == SQLITE_NULL
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        return try decodeOptionalValueType(type, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        switch type {
        case let v as ValueType.Type:
            return try decodeGenericOptionalValueType(v, forKey: key) as? T
        case let o as Object.Type:
            return try decodeGenericOptionalObject(o, forKey: key) as? T
        default:
            throw CodableDBError.unsupportedType
        }
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try decodeValueType(type, forKey: key)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try decodeValueType(type, forKey: key)
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T  {
        switch T.self {
        case let t as ValueType.Type:
            guard let valueType = try decodeGenericValueType(t, forKey: key) as? T else {
                throw CodableDBError.unsupportedType
            }
            return valueType
        case let o as Object.Type:
            guard let object = try decodeGenericObject(o, forKey: key) as? T else {
                throw CodableDBError.unsupportedType
            }
            return object
        default:
            throw CodableDBError.unsupportedType
        }
    }

    func decodeGenericValueType(_ type: ValueType.Type, forKey key: Key) throws -> ValueType {
        defer { index += 1 }
        return try type.decode(rowPointer: pointer, index: index)
    }

    func decodeValueType<V: ValueType>(_ type: V.Type, forKey key: Key) throws -> V {
        return try decodeGenericValueType(type, forKey: key) as! V
    }

    func decodeGenericOptionalValueType(_ type: ValueType.Type, forKey key: Key) throws -> ValueType? {
        guard try !decodeNil(forKey: key) else { return nil }
        return try decodeGenericValueType(type, forKey: key)
    }

    func decodeOptionalValueType<V: ValueType>(_ type: V.Type, forKey key: Key) throws -> V? {
        return try decodeGenericOptionalValueType(type, forKey: key) as? V
    }

    func decodeGenericOptionalObject(_ type: Object.Type, forKey key: Key) throws -> Object? {
        guard sqlite3_column_type(pointer, index) != SQLITE_NULL else {
            index += 1
            return nil
        }
        return try decodeGenericObject(type, forKey: key)
    }

    func decodeGenericObject(_ type: Object.Type, forKey key: Key) throws -> Object {
        defer { index += 1 }
        let value: ValueType
        switch sqlite3_column_type(pointer, index) {
        case SQLITE_INTEGER:
            value = try decode(Int64.self, forKey: key)
        case SQLITE_TEXT:
            value = try decode(String.self, forKey: key)
        case SQLITE_FLOAT:
            value = try decode(Double.self, forKey: key)
        case SQLITE_NULL:
            throw CodableDBError.unsupportedType
        case SQLITE_BLOB:
            throw CodableDBError.unsupportedType
        default:
            throw CodableDBError.unsupportedType
        }
        guard let object = try type.getWithPrimaryKey(value: value, database: database) else {
            throw CodableDBError.inconsistentData(description: "Could not find value for key \(key) in database.")
        }
        return object
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw CodableDBError.unsupportedType
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw CodableDBError.unsupportedType
    }

    func superDecoder() throws -> Decoder {
        throw CodableDBError.unsupportedType
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        throw CodableDBError.unsupportedType
    }
}

fileprivate extension Object {
    fileprivate static func getWithPrimaryKey(value: ValueType, database: Database) throws -> Self? {
        return try database.getAll(self, filteredBy: .custom(databaseRepresentation: "\(primaryKey.stringValue) = \(value.databaseRepresentation)")).first
    }
}
