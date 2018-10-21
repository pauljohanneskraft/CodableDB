import XCTest
import CodableDB

struct ComposedTestObject: Object, KeyPathCodable, Equatable {
    static func codingKey(for keyPath: PartialKeyPath<ComposedTestObject>) -> CodingKey! {
        switch keyPath {
        case \ComposedTestObject.testObject:
            return CodingKeys.testObject
        default:
            return nil
        }
    }

    var testObject: TestObject

    static var primaryKey: CodingKey {
        return CodingKeys.testObject
    }
}

struct TestObject: Object, KeyPathCodable, Equatable {
    static func codingKey(for keyPath: PartialKeyPath<TestObject>) -> CodingKey! {
        switch keyPath {
        case \TestObject.string:
            return CodingKeys.string
        case \TestObject.int:
            return CodingKeys.int
        case \TestObject.int8:
            return CodingKeys.int8
        case \TestObject.int16:
            return CodingKeys.int16
        case \TestObject.int32:
            return CodingKeys.int32
        case \TestObject.int64:
            return CodingKeys.int64
        case \TestObject.uint:
            return CodingKeys.uint
        case \TestObject.uint8:
            return CodingKeys.uint8
        case \TestObject.uint16:
            return CodingKeys.uint16
        case \TestObject.uint32:
            return CodingKeys.uint32
        case \TestObject.uint64:
            return CodingKeys.uint64
        case \TestObject.double:
            return CodingKeys.double
        case \TestObject.float:
            return CodingKeys.float
        case \TestObject.cgFloat:
            return CodingKeys.cgFloat
        default:
            return nil
        }
    }

    static var primaryKey: CodingKey {
        return CodingKeys.string
    }

    var string: String
    var int: Int
    var int8: Int8
    var int16: Int16
    var int32: Int32
    var int64: Int64
    var uint: UInt
    var uint8: UInt8
    var uint16: UInt16
    var uint32: UInt32
    var uint64: UInt64
    var double: Double
    var float: Float
    var cgFloat: CGFloat
    var intOptional: Int?
}

class Tests: XCTestCase {
    func testExample() {
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dbPath = url.appendingPathComponent("db.sqlite")

        print(FileManager.default.fileExists(atPath: dbPath.path))
        try? FileManager.default.removeItem(at: dbPath)

        let db: DatabaseProtocol = try! Database(filePath: dbPath)


        var insert = TestObject(string: "insert", int: 0, int8: .max, int16: .max, int32: .max, int64: .max, uint: UInt(Int.max), uint8: .max, uint16: .max, uint32: .max, uint64: UInt64(Int.max), double: 0.1, float: 0.1, cgFloat: 0.1, intOptional: nil)

        let composed = ComposedTestObject(testObject: insert)

        do {
            try db.insert(composed)
        } catch let error {
            assertionFailure("\(error)")
        }

        XCTAssertEqual(try! db.getAll(ComposedTestObject.self).count, 1)

        print("will insert", db, insert)

        try! db.update(insert)

        let values = try! db.getAll(TestObject.self)

        XCTAssertEqual(values, [insert])
        XCTAssertEqual(try! db.getAll(TestObject.self, sortedBy: .by(\.string), filteredBy: \.string == insert.string), [insert])
        XCTAssertEqual(try! db.getAll(TestObject.self, filteredBy: \.string == insert.string || \.int < .min), [insert])

        insert.intOptional = 5

        try! db.update(insert)

        XCTAssertEqual(try! db.getAll(TestObject.self), [insert])
        XCTAssertEqual(try! db.getAll(TestObject.self, sortedBy: .by(\.string), filteredBy: \.string == insert.string), [insert])
        XCTAssertEqual(try! db.getAll(TestObject.self, filteredBy: \.string == insert.string || \.int < .min), [insert])

        try! db.delete(insert)

        XCTAssertEqual(try! db.getAll(TestObject.self), [])
        XCTAssertEqual(try! db.getAll(TestObject.self, sortedBy: .by(\.string), filteredBy: \.string == insert.string), [])
        XCTAssertEqual(try! db.getAll(TestObject.self, filteredBy: \.string == insert.string || \.int < .min), [])

        try! db.insert(insert)

        let db2 = try! Database(filePath: dbPath)

        print(try! db2.getAll(TestObject.self))
    }
}
