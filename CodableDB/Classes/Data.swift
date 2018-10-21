//
//  Data.swift
//  CodableDB
//
//  Created by Paul Kraft on 03.10.18.
//

public protocol Data: Codable {

}

public protocol EncodableValueType: Data {
    var databaseRepresentation: String { get }
    static var databaseType: String { get }
}

public protocol DecodableValueType: Data {
    static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Self
}

public protocol ValueType: EncodableValueType, DecodableValueType {
}

extension EncodableValueType {
    static var nonNilDatabaseType: String {
        return databaseType + " NOT NULL"
    }
}

extension ValueType where Self: CaseIterable {
    var databaseRepresentation: String {
        return String(describing: self).databaseRepresentation
    }

    static var databaseType: String {
        let cases = allCases
            .map { $0.databaseRepresentation }
            .joined(separator: ", ")

        return "ENUM(" + cases + ")"
    }
}

public protocol Object: Data {
    static var identifier: String { get }
    static var primaryKey: CodingKey { get }
}

extension Object {
    public static var identifier: String {
        return String(describing: self)
    }
}

import SQLite3

extension String: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> String {
        guard let data = sqlite3_column_text(rowPointer, index) else {
            throw CodableDBError.unsupportedType
        }
        return String(cString: data)
    }

    public var databaseRepresentation: String {
        let escaped = addingPercentEncoding(withAllowedCharacters: .databaseAllowed) ?? description
        return "\"" + escaped + "\""
    }

    public static var databaseType: String {
        return "LONGTEXT"
    }
}

extension Bool: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Bool {
        return sqlite3_column_int(rowPointer, index) != 0
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "TINYINT"
    }
}

extension Int: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int {
        return Int(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return Int64.databaseType
    }
}

extension Double: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Double {
        return sqlite3_column_double(rowPointer, index)
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "DOUBLE"
    }
}

extension Float: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Float {
        return Float(sqlite3_column_double(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "FLOAT"
    }
}

extension Int8: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int8 {
        return Int8(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "TINYINT"
    }
}

extension Int16: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int16 {
        return Int16(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "SMALLINT"
    }
}

extension Int32: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int32 {
        return Int32(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "INT"
    }
}

extension Int64: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int64 {
        return Int64(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "BIGINT"
    }
}

extension UInt: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt {
        return UInt(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return UInt64.databaseType
    }
}

extension UInt32: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt32 {
        return UInt32(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "INT UNSIGNED"
    }
}

extension UInt64: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt64 {
        return UInt64(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String {
    return description
    }

    public static var databaseType: String {
        return "BIGINT UNSIGNED"
    }
}

extension UInt8: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt8 {
        return UInt8(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "TINYINT UNSIGNED"
    }
}

extension UInt16: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt16 {
        return UInt16(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "SMALLINT UNSIGNED"
    }
}

extension CGFloat: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> CGFloat {
        return CGFloat(sqlite3_column_double(rowPointer, index))
    }

    public var databaseRepresentation: String {
        return description
    }

    public static var databaseType: String {
        return "DOUBLE"
    }
}

public protocol DatabaseRepresentable: EncodableValueType {
    init(databaseRepresentation: String) throws
}

private let databaseRepresentationSeparator: Character = ","

extension Array: Data, EncodableValueType, DecodableValueType, ValueType where Element: DatabaseRepresentable {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> [Element] {
        return try String
            .decode(rowPointer: rowPointer, index: index)
            .split(separator: databaseRepresentationSeparator)
            .map { try Element(databaseRepresentation: String($0)) }
    }

    public static var databaseType: String {
        return "LONGTEXT"
    }

    public var databaseRepresentation: String {
        return self
            .map { $0.databaseRepresentation }
            .joined(separator: String(databaseRepresentationSeparator))
    }
}

extension Date: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Date {
        let string = try String.decode(rowPointer: rowPointer, index: index)
        guard let date =  databaseFormatter.date(from: string) else {
            throw CodableDBError.unsupportedType // TODO: Figure out which error fits best
        }
        return date
    }

    private static let databaseFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-DD HH:mm:SS" // TODO: Check date format
        return formatter
    }()

    public var databaseRepresentation: String {
        return Date.databaseFormatter.string(from: self)
    }

    public static var databaseType: String {
        return "DATETIME"
    }
}
