import Foundation

/// Encodes `Object` types into `ColumnEncoding` arrays for SQL insertion.
class DatabaseEncoder {
    func encode<O: Object>(_ object: O) throws -> [ColumnEncoding] {
        let encoder = DatabaseObjectEncoder<O>()
        try object.encode(to: encoder)
        return encoder.information[String(describing: O.self)]?.columns ?? []
    }

    func encodingInformation<O: Object>(for object: O) throws -> EncodingInformationStore {
        let encoder = DatabaseObjectEncoder<O>()
        try object.encode(to: encoder)
        return encoder.information
    }
}

// MARK: - Encoder

private protocol HasEncodingInformation {
    var information: EncodingInformationStore { get }
}

private class DatabaseObjectEncoder<O: Object>: Encoder {
    var codingPath: [CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    var containers = [any HasEncodingInformation]()

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = DatabaseKeyedEncodingContainer<O, Key>()
        containers.append(container)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer { fatalError("Unkeyed containers are not supported") }
    func singleValueContainer() -> SingleValueEncodingContainer { fatalError("Single value containers are not supported") }

    var information: EncodingInformationStore {
        containers.reduce(into: EncodingInformationStore()) { acc, container in
            acc.merge(container.information) { existing, _ in existing }
        }
    }
}

// MARK: - Keyed Encoding Container

private class DatabaseKeyedEncodingContainer<O: Object, Key: CodingKey>: KeyedEncodingContainerProtocol, HasEncodingInformation {
    var codingPath = [CodingKey]()
    var information = EncodingInformationStore()

    private let nullStringValue = "NULL"

    func encodeNil(forKey key: Key) throws {
        throw CodableDBError.unsupportedType
    }

    // MARK: Optional Primitives

    func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }
    func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try encodeOptionalValueType(value, forKey: key) }

    func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
        switch value {
        case let v as (any ValueType)?:
            guard let type = T.self as? any ValueType.Type else { throw CodableDBError.unsupportedType }
            try encodeOptionalGenericValueType(v, forKey: key, type: type)
        case let o as (any Object)?:
            guard let type = T.self as? any Object.Type else { throw CodableDBError.unsupportedType }
            try encodeOptionalGenericObject(o, forKey: key, type: type)
        default:
            throw CodableDBError.unsupportedType
        }
    }

    // MARK: Required Primitives

    func encode(_ value: Bool, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: String, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Double, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Float, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Int, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Int8, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Int16, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Int32, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: Int64, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: UInt, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: UInt8, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: UInt16, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: UInt32, forKey key: Key) throws { try encodeValueType(value, forKey: key) }
    func encode(_ value: UInt64, forKey key: Key) throws { try encodeValueType(value, forKey: key) }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        switch value {
        case let v as any ValueType: try encodeValueType(v, forKey: key)
        case let o as any Object: try encodeObject(o, forKey: key)
        default: throw CodableDBError.unsupportedType
        }
    }

    // MARK: Value Type Encoding

    private func encodeOptionalValueType<V: ValueType>(_ value: V?, forKey key: Key) throws {
        try encodeOptionalGenericValueType(value, forKey: key, type: V.self)
    }

    private func encodeOptionalGenericValueType(_ value: (any ValueType)?, forKey key: Key, type: any ValueType.Type) throws {
        let column = ColumnEncoding(
            key: key,
            type: type.databaseType,
            value: value?.databaseRepresentation ?? nullStringValue
        )
        addColumn(column)
    }

    private func encodeValueType(_ value: any ValueType, forKey key: Key) throws {
        let column = ColumnEncoding(
            key: key,
            type: type(of: value).nonNilDatabaseType,
            value: value.databaseRepresentation
        )
        addColumn(column)
    }

    // MARK: Object Encoding

    private func encodeObject(_ value: any Object, forKey key: Key) throws {
        let columns = try DatabaseEncoder().encode(value)
        let primaryKey = type(of: value).primaryKey
        guard let primaryKeyValue = columns.first(where: { $0.key.stringValue == primaryKey.stringValue }) else {
            throw CodableDBError.unsupportedType
        }
        addColumns(columns, type: type(of: value))
        addColumn(ColumnEncoding(key: key, type: String.nonNilDatabaseType, value: primaryKeyValue.value))
    }

    private func encodeOptionalGenericObject(_ value: (any Object)?, forKey key: Key, type: any Object.Type) throws {
        guard let columns = try value.map({ try DatabaseEncoder().encode($0) }) else {
            addColumn(ColumnEncoding(key: key, type: String.databaseType, value: nullStringValue))
            return
        }
        let primaryKey = type.primaryKey
        guard let primaryKeyValue = columns.first(where: { $0.key.stringValue == primaryKey.stringValue }) else {
            throw CodableDBError.unsupportedType
        }
        addColumns(columns, type: type)
        addColumn(ColumnEncoding(key: key, type: String.databaseType, value: primaryKeyValue.value))
    }

    // MARK: Storage

    private func addColumn(_ column: ColumnEncoding) {
        addColumns([column], type: O.self)
    }

    private func addColumns(_ newColumns: [ColumnEncoding], type: any Object.Type) {
        guard let existing = information[type.identifier] else {
            information[type.identifier] = TableEncoding(type: type, columns: newColumns)
            return
        }
        let unique = newColumns.filter { new in
            !existing.columns.contains { $0.key.stringValue == new.key.stringValue }
        }
        information[type.identifier] = TableEncoding(type: type, columns: existing.columns + unique)
    }

    // MARK: Unsupported

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> { fatalError("Nested containers are not supported") }
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer { fatalError("Unkeyed containers are not supported") }
    func superEncoder() -> Encoder { fatalError("Super encoding is not supported") }
    func superEncoder(forKey key: Key) -> Encoder { fatalError("Super encoding is not supported") }
}
