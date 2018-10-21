//
//  DatabaseEncoder.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

typealias EncodingInformation = (key: CodingKey, type: String, value: String)

typealias EncodingInformationStore = [String: (Object.Type, [EncodingInformation])]

class DatabaseEncoder {
    func encode<O: Object>(_ object: O) throws -> [EncodingInformation] {
        let encoder = DatabaseObjectEncoder<O>()
        try object.encode(to: encoder)
        return encoder.information[String(describing: O.self)]?.1 ?? []
    }

    func encodingInformation<O: Object>(for object: O) throws -> EncodingInformationStore {
        let encoder = DatabaseObjectEncoder<O>()
        try object.encode(to: encoder)
        return encoder.information
    }
}

protocol HasEncodingInformation {
    var information: EncodingInformationStore { get }
}

class DatabaseObjectEncoder<O: Object>: Encoder {

    var codingPath: [CodingKey] {
        return []
    }

    var userInfo: [CodingUserInfoKey : Any] {
        return [:]
    }

    var containers = [HasEncodingInformation]()

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = DatabaseKeyedEncodingContainer<O, Key>()
        containers.append(container)
        return KeyedEncodingContainer<Key>(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError()
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError()
    }

    var information: EncodingInformationStore {
        let initialResult = EncodingInformationStore()
        return containers.reduce(into: initialResult) { acc, con in
            acc.merge(con.information, uniquingKeysWith: { a, b in a })
        }
    }
}

class DatabaseKeyedEncodingContainer<O: Object, Key: CodingKey>: KeyedEncodingContainerProtocol, HasEncodingInformation {
    var codingPath = [CodingKey]()
    var information = EncodingInformationStore()

    let nullStringValue = "NULL"

    func encodeNil(forKey key: Key) throws {
        throw CodableDBError.unsupportedType
    }

    func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        try encodeOptionalValueType(value, forKey: key)
    }

    func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
        switch value {
        case let v as ValueType?:
            guard let type = T.self as? ValueType.Type else {
                throw CodableDBError.unsupportedType
            }
            try encodeOptionalGenericValueType(v, forKey: key, type: type)
        case let o as Object?:
            guard let type = T.self as? Object.Type else {
                throw CodableDBError.unsupportedType
            }
            try encodeOptionalGenericObject(o, forKey: key, type: type)
        default:
            throw CodableDBError.unsupportedType
        }
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: String, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Double, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Float, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Int, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Int8, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Int16, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
        try encodeValueType(value, forKey: key)
    }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        switch value {
        case let v as ValueType:
            try encodeValueType(v, forKey: key)
        case let o as Object:
            try encodeObject(o, forKey: key)
        default:
            throw CodableDBError.unsupportedType
        }
    }

    func encodeOptionalValueType<V: ValueType>(_ value: V?, forKey key: Key) throws {
        try encodeOptionalGenericValueType(value, forKey: key, type: V.self)
    }

    func encodeOptionalGenericValueType(_ value: ValueType?, forKey key: Key, type: ValueType.Type) throws {
        let info: EncodingInformation = (key: key, type: type.databaseType, value: value?.databaseRepresentation ?? nullStringValue)
        addEncodingInformation(info)
    }

    func encodeValueType(_ value: ValueType, forKey key: Key) throws {
        let info: EncodingInformation = (key: key, type: type(of: value).nonNilDatabaseType, value: value.databaseRepresentation)
        addEncodingInformation(info)
    }

    func encodeObject(_ value: Object, forKey key: Key) throws {
        let valueEncoding = try value.encoded()
        let primaryKey = type(of: value).primaryKey
        guard let primaryKeyValue = valueEncoding.first(where: { $0.key.stringValue == primaryKey.stringValue }) else {
            throw CodableDBError.unsupportedType
        }
        addEncodingInformation(valueEncoding, type: type(of: value))
        addEncodingInformation((key: key, type: String.nonNilDatabaseType, value: primaryKeyValue.value))
    }

    func encodeOptionalObject<O: Object>(_ value: O?, forKey key: Key) throws {
        try encodeOptionalGenericObject(value, forKey: key, type: O.self)
    }

    func encodeOptionalGenericObject(_ value: Object?, forKey key: Key, type: Object.Type) throws {
        guard let valueEncoding = try value?.encoded() else {
            addEncodingInformation((key: key, type: String.databaseType, value: nullStringValue))
            return
        }
        let primaryKey = type.primaryKey
        guard let primaryKeyValue = valueEncoding.first(where: { $0.key.stringValue == primaryKey.stringValue }) else {
            throw CodableDBError.unsupportedType
        }
        addEncodingInformation(valueEncoding, type: type)
        addEncodingInformation((key: key, type: String.databaseType, value: primaryKeyValue.value))
    }

    private func addEncodingInformation(_ information: EncodingInformation) {
        return addEncodingInformation([information], type: O.self)
    }

    private func addEncodingInformation(_ newInformation: [EncodingInformation], type: Object.Type) {
        guard let previousInformation = information[type.identifier] else {
            information[type.identifier] = (type, newInformation)
            return
        }
        let uniqueNewInformation = newInformation
            .filter { newInfo in
                !previousInformation.1.contains(where: { $0.key.stringValue == newInfo.key.stringValue })
            }

        information[type.identifier] = (type, previousInformation.1 + uniqueNewInformation)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError()
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError()
    }

    func superEncoder() -> Encoder {
        fatalError()
    }

    func superEncoder(forKey key: Key) -> Encoder {
        fatalError()
    }
}

extension Optional {
    mutating func appendOrCreate<Element>(_ element: Element) where Wrapped == Array<Element> {
        switch self {
        case let .some(array):
            var arr = array
            arr.append(element)
            self = .some(arr)
        case .none:
            self = .some([element])
        }
    }
}

fileprivate extension Object {
    fileprivate func encoded() throws -> [EncodingInformation] {
        return try DatabaseEncoder().encode(self)
    }
}
