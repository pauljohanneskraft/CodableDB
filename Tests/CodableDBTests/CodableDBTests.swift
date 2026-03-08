import Foundation
import Sift
import Testing

@testable import CodableDB

// MARK: - Test Models

/// A model exercising every supported primitive type.
struct TestObject: Object, KeyPathCodable, Equatable {
    static var primaryKey: CodingKey { CodingKeys.string }

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

/// A minimal model with just a string primary key.
struct SimpleObject: Object, KeyPathCodable, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }
    var id: String
    var name: String
    var score: Int
}

/// A model that nests another `Object` as a foreign-key reference.
struct ComposedTestObject: Object, KeyPathCodable, Equatable {
    static var primaryKey: CodingKey { CodingKeys.testObject }
    var testObject: TestObject
}

/// A model with a boolean field.
struct FlagObject: Object, KeyPathCodable, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }
    var id: String
    var isActive: Bool
}

// MARK: - Helpers

private func makeTestDatabase() throws -> Database {
    let url = try FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let dbPath = url.appendingPathComponent("codabledb-test-\(UUID().uuidString).sqlite")
    return try Database(filePath: dbPath)
}

private func makeTestObject(
    string: String = "test",
    int: Int = 0,
    intOptional: Int? = nil
) -> TestObject {
    TestObject(
        string: string,
        int: int,
        int8: .max,
        int16: .max,
        int32: .max,
        int64: .max,
        uint: UInt(Int.max),
        uint8: .max,
        uint16: .max,
        uint32: .max,
        uint64: UInt64(Int.max),
        double: 0.1,
        float: 0.1,
        cgFloat: 0.1,
        intOptional: intOptional
    )
}

// MARK: - CRUD Basics

@Suite("CRUD Operations")
struct CRUDTests {

    @Test func insertAndRetrieve() throws {
        let db = try makeTestDatabase()
        let object = makeTestObject()

        try db.insert(object)
        let results = try db.getAll(TestObject.self)

        #expect(results == [object])
    }

    @Test func insertMultipleObjects() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        let c = SimpleObject(id: "c", name: "Charlie", score: 90)

        try db.insert(a)
        try db.insert(b)
        try db.insert(c)

        let results = try db.getAll(SimpleObject.self)
        #expect(results.count == 3)
        #expect(results.contains(a))
        #expect(results.contains(b))
        #expect(results.contains(c))
    }

    @Test func updateObject() throws {
        let db = try makeTestDatabase()
        var object = makeTestObject()
        try db.insert(object)

        object.intOptional = 42
        try db.update(object)

        let results = try db.getAll(TestObject.self)
        #expect(results == [object])
        #expect(results.first?.intOptional == 42)
    }

    @Test func updatePreservesOtherRows() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        var b = SimpleObject(id: "b", name: "Bob", score: 80)
        try db.insert(a)
        try db.insert(b)

        b.score = 95
        try db.update(b)

        let results = try db.getAll(SimpleObject.self)
        #expect(results.contains(a))
        #expect(results.contains(b))
        #expect(results.first(where: { $0.id == "b" })?.score == 95)
    }

    @Test func deleteObject() throws {
        let db = try makeTestDatabase()
        let object = makeTestObject()
        try db.insert(object)

        try db.delete(object)

        let results = try db.getAll(TestObject.self)
        #expect(results.isEmpty)
    }

    @Test func deleteOnlyTargetedRow() throws {
        let db = try makeTestDatabase()
        let keep = SimpleObject(id: "keep", name: "Keeper", score: 1)
        let remove = SimpleObject(id: "remove", name: "Goner", score: 2)
        try db.insert(keep)
        try db.insert(remove)

        try db.delete(remove)

        let results = try db.getAll(SimpleObject.self)
        #expect(results == [keep])
    }

    @Test func getAllFromEmptyTable() throws {
        let db = try makeTestDatabase()
        // Insert then delete to ensure table exists but is empty
        let object = SimpleObject(id: "tmp", name: "tmp", score: 0)
        try db.insert(object)
        try db.delete(object)

        let results = try db.getAll(SimpleObject.self)
        #expect(results.isEmpty)
    }

    @Test func insertDuplicatePrimaryKeyThrows() throws {
        let db = try makeTestDatabase()
        let object = SimpleObject(id: "dup", name: "First", score: 1)
        try db.insert(object)

        #expect(throws: (any Error).self) {
            try db.insert(SimpleObject(id: "dup", name: "Second", score: 2))
        }
    }
}

// MARK: - Primitive Types

@Suite("Primitive Value Types")
struct PrimitiveTypeTests {

    @Test func allPrimitiveTypesRoundTrip() throws {
        let db = try makeTestDatabase()
        let object = TestObject(
            string: "hello world",
            int: -42,
            int8: Int8.min,
            int16: Int16.min,
            int32: Int32.min,
            int64: Int64.min,
            uint: 0,
            uint8: 0,
            uint16: 0,
            uint32: 0,
            uint64: 0,
            double: 3.14159265358979,
            float: 2.71828,
            cgFloat: -99.5,
            intOptional: nil
        )

        try db.insert(object)
        let result = try db.getAll(TestObject.self).first

        #expect(result?.string == object.string)
        #expect(result?.int == object.int)
        #expect(result?.int8 == object.int8)
        #expect(result?.int16 == object.int16)
        #expect(result?.int32 == object.int32)
        #expect(result?.int64 == object.int64)
        #expect(result?.uint == object.uint)
        #expect(result?.uint8 == object.uint8)
        #expect(result?.uint16 == object.uint16)
        #expect(result?.uint32 == object.uint32)
        #expect(result?.uint64 == object.uint64)
        #expect(result?.float == object.float)
        #expect(result?.cgFloat == object.cgFloat)
        #expect(result?.intOptional == nil)
    }

    @Test func maxValues() throws {
        let db = try makeTestDatabase()
        let object = makeTestObject(string: "max-values")
        try db.insert(object)

        let result = try #require(try db.getAll(TestObject.self).first)
        #expect(result.int8 == Int8.max)
        #expect(result.int16 == Int16.max)
        #expect(result.int32 == Int32.max)
        #expect(result.int64 == Int64.max)
        #expect(result.uint8 == UInt8.max)
        #expect(result.uint16 == UInt16.max)
        #expect(result.uint32 == UInt32.max)
    }

    @Test func booleanRoundTrip() throws {
        let db = try makeTestDatabase()
        let active = FlagObject(id: "a", isActive: true)
        let inactive = FlagObject(id: "b", isActive: false)
        try db.insert(active)
        try db.insert(inactive)

        let results = try db.getAll(FlagObject.self)
        #expect(results.contains(active))
        #expect(results.contains(inactive))
    }

    @Test func optionalNilRoundTrip() throws {
        let db = try makeTestDatabase()
        let object = makeTestObject(string: "nil-optional", intOptional: nil)
        try db.insert(object)

        let result = try #require(try db.getAll(TestObject.self).first)
        #expect(result.intOptional == nil)
    }

    @Test func optionalValueRoundTrip() throws {
        let db = try makeTestDatabase()
        let object = makeTestObject(string: "has-optional", intOptional: 999)
        try db.insert(object)

        let result = try #require(try db.getAll(TestObject.self).first)
        #expect(result.intOptional == 999)
    }

    @Test func specialCharactersInStrings() throws {
        let db = try makeTestDatabase()
        let object = SimpleObject(id: "special", name: "O'Reilly & Sons (™) — \"quoted\"", score: 1)
        try db.insert(object)

        let result = try #require(try db.getAll(SimpleObject.self).first)
        #expect(result.id == "special")
    }

    @Test func emptyString() throws {
        let db = try makeTestDatabase()
        let object = SimpleObject(id: "empty", name: "", score: 0)
        try db.insert(object)

        let result = try #require(try db.getAll(SimpleObject.self).first)
        #expect(result.name == "")
    }
}

// MARK: - Optional Handling

@Suite("Optional Fields")
struct OptionalTests {

    @Test func updateNilToValue() throws {
        let db = try makeTestDatabase()
        var object = makeTestObject(string: "nil-to-val", intOptional: nil)
        try db.insert(object)

        object.intOptional = 7
        try db.update(object)

        let result = try #require(try db.getAll(TestObject.self).first)
        #expect(result.intOptional == 7)
    }

    @Test func updateValueToNil() throws {
        let db = try makeTestDatabase()
        var object = makeTestObject(string: "val-to-nil", intOptional: 42)
        try db.insert(object)

        object.intOptional = nil
        try db.update(object)

        let result = try #require(try db.getAll(TestObject.self).first)
        #expect(result.intOptional == nil)
    }
}

// MARK: - Composed Objects

@Suite("Composed Objects")
struct ComposedObjectTests {

    @Test func insertAndRetrieveComposedObject() throws {
        let db = try makeTestDatabase()
        let inner = makeTestObject(string: "inner")
        let composed = ComposedTestObject(testObject: inner)

        try db.insert(composed)

        let results = try db.getAll(ComposedTestObject.self)
        #expect(results.count == 1)
        #expect(results.first?.testObject.string == "inner")
    }

    @Test func composedObjectRetrievesItsInner() throws {
        let db = try makeTestDatabase()
        let inner = makeTestObject(string: "inner-check")
        let composed = ComposedTestObject(testObject: inner)

        try db.insert(composed)

        let innerResults = try db.getAll(TestObject.self)
        #expect(innerResults.contains(inner))
    }
}

// MARK: - Filtering (Sift Predicates)

@Suite("Filtering")
struct FilterTests {

    @Test func filterByEquality() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        try db.insert(a)
        try db.insert(b)

        let results = try db.getAll(
            SimpleObject.self,
            filteredBy: \SimpleObject.id == "a"
        )
        #expect(results == [a])
    }

    @Test func filterByLessThan() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        try db.insert(a)
        try db.insert(b)

        let results = try db.getAll(
            SimpleObject.self,
            filteredBy: \SimpleObject.score < 90
        )
        #expect(results == [b])
    }

    @Test func filterByGreaterThan() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        try db.insert(a)
        try db.insert(b)

        let results = try db.getAll(
            SimpleObject.self,
            filteredBy: \SimpleObject.score > 90
        )
        #expect(results == [a])
    }

    @Test func filterWithAnd() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        let c = SimpleObject(id: "c", name: "Charlie", score: 100)
        try db.insert(a)
        try db.insert(b)
        try db.insert(c)

        let results = try db.getAll(
            SimpleObject.self,
            filteredBy: \SimpleObject.score > 90 && \SimpleObject.id == "a"
        )
        #expect(results == [a])
    }

    @Test func filterWithOr() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        let c = SimpleObject(id: "c", name: "Charlie", score: 90)
        try db.insert(a)
        try db.insert(b)
        try db.insert(c)

        let results = try db.getAll(
            SimpleObject.self,
            filteredBy: \SimpleObject.id == "a" || \SimpleObject.id == "c"
        )
        #expect(results.count == 2)
        #expect(results.contains(a))
        #expect(results.contains(c))
    }

    @Test func filterReturnsEmptyWhenNoMatch() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        try db.insert(a)

        let results = try db.getAll(
            SimpleObject.self,
            filteredBy: \SimpleObject.score > 200
        )
        #expect(results.isEmpty)
    }

    @Test func filterAfterDelete() throws {
        let db = try makeTestDatabase()
        let object = makeTestObject()
        try db.insert(object)
        try db.delete(object)

        let results = try db.getAll(
            TestObject.self,
            filteredBy: \TestObject.string == object.string
        )
        #expect(results.isEmpty)
    }
}

// MARK: - Sorting (Sift Orders)

@Suite("Sorting")
struct SortTests {

    @Test func sortAscending() throws {
        let db = try makeTestDatabase()
        let c = SimpleObject(id: "c", name: "Charlie", score: 90)
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        try db.insert(c)
        try db.insert(a)
        try db.insert(b)

        let results = try db.getAll(
            SimpleObject.self,
            sortedBy: Ascending(\SimpleObject.id)
        )
        #expect(results.map(\.id) == ["a", "b", "c"])
    }

    @Test func sortDescending() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        let c = SimpleObject(id: "c", name: "Charlie", score: 90)
        try db.insert(a)
        try db.insert(b)
        try db.insert(c)

        let results = try db.getAll(
            SimpleObject.self,
            sortedBy: Descending(\SimpleObject.score)
        )
        #expect(results.map(\.score) == [100, 90, 80])
    }

    @Test func sortWithFilter() throws {
        let db = try makeTestDatabase()
        let a = SimpleObject(id: "a", name: "Alice", score: 100)
        let b = SimpleObject(id: "b", name: "Bob", score: 80)
        let c = SimpleObject(id: "c", name: "Charlie", score: 90)
        try db.insert(a)
        try db.insert(b)
        try db.insert(c)

        let results = try db.getAll(
            SimpleObject.self,
            sortedBy: Ascending(\SimpleObject.score),
            filteredBy: \SimpleObject.score >= 90
        )
        #expect(results.map(\.id) == ["c", "a"])
    }
}

// MARK: - Count

@Suite("Count")
struct CountTests {

    @Test func countAll() throws {
        let db = try makeTestDatabase()
        try db.insert(SimpleObject(id: "a", name: "A", score: 1))
        try db.insert(SimpleObject(id: "b", name: "B", score: 2))
        try db.insert(SimpleObject(id: "c", name: "C", score: 3))

        let count = try db.count(SimpleObject.self)
        #expect(count == 3)
    }

    @Test func countAfterDelete() throws {
        let db = try makeTestDatabase()
        let object = SimpleObject(id: "x", name: "X", score: 1)
        try db.insert(object)
        try db.delete(object)

        let count = try db.count(SimpleObject.self)
        #expect(count == 0)
    }
}

// MARK: - Persistence

@Suite("Persistence")
struct PersistenceTests {

    @Test func persistenceAcrossInstances() throws {
        let url = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbPath = url.appendingPathComponent("codabledb-persist-\(UUID().uuidString).sqlite")

        let db1 = try Database(filePath: dbPath)
        let object = makeTestObject(string: "persist", intOptional: 5)
        try db1.insert(object)

        let db2 = try Database(filePath: dbPath)
        let results = try db2.getAll(TestObject.self)
        #expect(results == [object])
    }

    @Test func multipleTablesInSameDatabase() throws {
        let db = try makeTestDatabase()
        let simple = SimpleObject(id: "s", name: "Simple", score: 10)
        let flag = FlagObject(id: "f", isActive: true)

        try db.insert(simple)
        try db.insert(flag)

        let simples = try db.getAll(SimpleObject.self)
        let flags = try db.getAll(FlagObject.self)

        #expect(simples == [simple])
        #expect(flags == [flag])
    }
}

// MARK: - Drop Table

@Suite("Drop Table")
struct DropTableTests {

    @Test func dropTableRemovesAllData() throws {
        let db = try makeTestDatabase()
        try db.insert(SimpleObject(id: "a", name: "Alice", score: 1))
        try db.insert(SimpleObject(id: "b", name: "Bob", score: 2))

        try db.dropTable(SimpleObject.self)

        // After dropping, re-inserting should work (table gets re-created)
        try db.insert(SimpleObject(id: "c", name: "Charlie", score: 3))
        let results = try db.getAll(SimpleObject.self)
        #expect(results.count == 1)
        #expect(results.first?.id == "c")
    }
}

// MARK: - Table Auto-Creation

@Suite("Table Auto-Creation")
struct AutoCreationTests {

    @Test func tableCreatedOnFirstInsert() throws {
        let db = try makeTestDatabase()
        // No prior setup needed — table should be created automatically
        let object = SimpleObject(id: "auto", name: "Auto", score: 1)
        try db.insert(object)

        let results = try db.getAll(SimpleObject.self)
        #expect(results == [object])
    }

    @Test func differentTypesGetSeparateTables() throws {
        let db = try makeTestDatabase()
        try db.insert(SimpleObject(id: "s1", name: "Simple", score: 1))
        try db.insert(FlagObject(id: "f1", isActive: true))

        #expect(try db.count(SimpleObject.self) == 1)
        #expect(try db.count(FlagObject.self) == 1)

        try db.dropTable(SimpleObject.self)
        // FlagObject table should be unaffected
        #expect(try db.count(FlagObject.self) == 1)
    }
}

// MARK: - Batch Operations

@Suite("Batch Operations")
struct BatchTests {

    @Test func insertAndDeleteMultiple() throws {
        let db = try makeTestDatabase()
        let objects = (0..<10).map { SimpleObject(id: "\($0)", name: "Item \($0)", score: $0) }
        for object in objects {
            try db.insert(object)
        }
        #expect(try db.count(SimpleObject.self) == 10)

        for object in objects.prefix(5) {
            try db.delete(object)
        }
        #expect(try db.count(SimpleObject.self) == 5)
    }

    @Test func updateMultipleRows() throws {
        let db = try makeTestDatabase()
        var objects = (0..<5).map { SimpleObject(id: "\($0)", name: "Name \($0)", score: $0 * 10) }
        for object in objects {
            try db.insert(object)
        }

        for i in objects.indices {
            objects[i].score += 1
            try db.update(objects[i])
        }

        let results = try db.getAll(SimpleObject.self)
        for object in objects {
            #expect(results.contains(object))
        }
    }
}

// MARK: - Edge Cases

@Suite("Edge Cases")
struct EdgeCaseTests {

    @Test func deleteNonExistentObjectDoesNotThrow() throws {
        let db = try makeTestDatabase()
        // Insert then delete to ensure table exists
        let existing = SimpleObject(id: "exists", name: "E", score: 0)
        try db.insert(existing)

        let ghost = SimpleObject(id: "ghost", name: "G", score: 0)
        // Deleting a non-existent row should not throw (DELETE WHERE returns done)
        try db.delete(ghost)

        let results = try db.getAll(SimpleObject.self)
        #expect(results == [existing])
    }

    @Test func updateNonExistentInsertsIt() throws {
        let db = try makeTestDatabase()
        let object = SimpleObject(id: "new", name: "New", score: 1)
        // update = delete (no-op) + insert
        try db.update(object)

        let results = try db.getAll(SimpleObject.self)
        #expect(results == [object])
    }

    @Test func longStringValue() throws {
        let db = try makeTestDatabase()
        let longName = String(repeating: "a", count: 10_000)
        let object = SimpleObject(id: "long", name: longName, score: 0)
        try db.insert(object)

        let result = try #require(try db.getAll(SimpleObject.self).first)
        #expect(result.name.count == 10_000)
    }
}
