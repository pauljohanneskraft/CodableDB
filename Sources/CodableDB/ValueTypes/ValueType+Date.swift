import Foundation
import SQLite3

extension Date: ValueType {
    private static let databaseFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    public static func decode(rowPointer: OpaquePointer, index: Int32) throws -> Date {
        let string = try String.decode(rowPointer: rowPointer, index: index)
        guard let date = databaseFormatter.date(from: string) else {
            throw CodableDBError.unsupportedType
        }
        return date
    }

    public var databaseRepresentation: String {
        Date.databaseFormatter.string(from: self)
    }

    public static var databaseType: String { "DATETIME" }
}
