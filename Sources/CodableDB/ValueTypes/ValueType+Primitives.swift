import Foundation
import SQLite3

// MARK: - String

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

    public static var databaseType: String { "LONGTEXT" }
}

// MARK: - Bool

extension Bool: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Bool {
        sqlite3_column_int(rowPointer, index) != 0
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "TINYINT" }
}

// MARK: - Int

extension Int: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int {
        Int(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { Int64.databaseType }
}

// MARK: - Double

extension Double: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Double {
        sqlite3_column_double(rowPointer, index)
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "DOUBLE" }
}

// MARK: - Float

extension Float: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Float {
        Float(sqlite3_column_double(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "FLOAT" }
}

// MARK: - Int8

extension Int8: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int8 {
        Int8(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "TINYINT" }
}

// MARK: - Int16

extension Int16: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int16 {
        Int16(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "SMALLINT" }
}

// MARK: - Int32

extension Int32: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int32 {
        Int32(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "INT" }
}

// MARK: - Int64

extension Int64: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Int64 {
        Int64(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "BIGINT" }
}

// MARK: - UInt

extension UInt: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt {
        UInt(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { UInt64.databaseType }
}

// MARK: - UInt8

extension UInt8: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt8 {
        UInt8(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "TINYINT UNSIGNED" }
}

// MARK: - UInt16

extension UInt16: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt16 {
        UInt16(sqlite3_column_int(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "SMALLINT UNSIGNED" }
}

// MARK: - UInt32

extension UInt32: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt32 {
        UInt32(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "INT UNSIGNED" }
}

// MARK: - UInt64

extension UInt64: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> UInt64 {
        UInt64(sqlite3_column_int64(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "BIGINT UNSIGNED" }
}

// MARK: - CGFloat

extension CGFloat: ValueType {
    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> CGFloat {
        CGFloat(sqlite3_column_double(rowPointer, index))
    }

    public var databaseRepresentation: String { description }
    public static var databaseType: String { "DOUBLE" }
}

// MARK: - CaseIterable ValueTypes

extension ValueType where Self: CaseIterable {
    public var databaseRepresentation: String {
        String(describing: self).databaseRepresentation
    }

    public static var databaseType: String {
        let cases = allCases.map { $0.databaseRepresentation }.joined(separator: ", ")
        return "ENUM(" + cases + ")"
    }
}
