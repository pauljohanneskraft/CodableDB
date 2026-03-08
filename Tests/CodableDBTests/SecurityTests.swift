import Foundation
import Sift
import Testing

@testable import CodableDB

// MARK: - Test Models for Security Testing

/// A model whose primary key is a string — the main injection target.
@Model
struct InjectionTarget: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }
    var id: String
    var value: String
    var score: Int
}

/// A model with optional string fields to test NULL/injection combos.
@Model
struct OptionalInjectionTarget: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }
    var id: String
    var notes: String?
}

/// A canary table used to verify it survives injection attempts.
@Model
struct Canary: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }
    var id: String
    var alive: Bool
}

/// A model with floating-point fields for boundary testing.
@Model
struct FloatTarget: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }
    var id: String
    var doubleVal: Double
    var floatVal: Float
}

// MARK: - Helpers

private func makeSecurityTestDatabase() throws -> Database {
    let url = try FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let dbPath = url.appendingPathComponent("codabledb-security-\(UUID().uuidString).sqlite")
    return try Database(filePath: dbPath)
}

/// Plants a canary row and returns a closure that verifies it survived.
private func plantCanary(in db: Database) throws -> () throws -> Void {
    let canary = Canary(id: "canary", alive: true)
    try db.insert(canary)
    return {
        let survivors = try db.getAll(Canary.self)
        #expect(survivors == [canary], "Canary was destroyed — SQL injection may have succeeded")
    }
}

// MARK: - Classic SQL Injection via String Values

@Suite("SQL Injection — String Values")
struct StringValueInjectionTests {

    @Test("Classic single-quote breakout: ' OR '1'='1")
    func classicOrInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let malicious = InjectionTarget(id: "evil", value: "' OR '1'='1", score: 0)
        try db.insert(malicious)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == 1)
        #expect(results.first?.value == "' OR '1'='1")
        try verifyCanary()
    }

    @Test("DROP TABLE injection in value: '; DROP TABLE Canary;--")
    func dropTableInValue() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let malicious = InjectionTarget(
            id: "dropper",
            value: "'; DROP TABLE Canary;--",
            score: 0
        )
        try db.insert(malicious)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.value == "'; DROP TABLE Canary;--")
        try verifyCanary()
    }

    @Test("DROP TABLE injection in primary key")
    func dropTableInPrimaryKey() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let malicious = InjectionTarget(
            id: "'; DROP TABLE Canary;--",
            value: "payload",
            score: 0
        )
        try db.insert(malicious)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == 1)
        #expect(results.first?.id == "'; DROP TABLE Canary;--")
        try verifyCanary()
    }

    @Test("UNION SELECT injection: ' UNION SELECT name FROM sqlite_master--")
    func unionSelectInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let malicious = InjectionTarget(
            id: "union",
            value: "' UNION SELECT name FROM sqlite_master--",
            score: 0
        )
        try db.insert(malicious)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.value == "' UNION SELECT name FROM sqlite_master--")
        try verifyCanary()
    }

    @Test("Stacked query injection: '; INSERT INTO InjectionTarget VALUES('hacked','pwned',999);--")
    func stackedQueryInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let payload = "'; INSERT INTO InjectionTarget VALUES('hacked','pwned',999);--"
        let malicious = InjectionTarget(id: "stacked", value: payload, score: 0)
        try db.insert(malicious)

        let results = try db.getAll(InjectionTarget.self)
        // Should only have the one legitimate row, not an injected 'hacked' row
        #expect(!results.contains(where: { $0.id == "hacked" }))
        #expect(results.first?.value == payload)
        try verifyCanary()
    }

    @Test("Semicolon-only injection: value is just ';'")
    func semicolonValue() throws {
        let db = try makeSecurityTestDatabase()
        let obj = InjectionTarget(id: "semi", value: ";", score: 0)
        try db.insert(obj)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.value == ";")
    }

    @Test("SQL comment injection: -- and /* */")
    func commentInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let dashComment = InjectionTarget(id: "dash", value: "before-- after", score: 0)
        let blockComment = InjectionTarget(id: "block", value: "before/* inside */after", score: 0)
        try db.insert(dashComment)
        try db.insert(blockComment)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.contains(where: { $0.value == "before-- after" }))
        #expect(results.contains(where: { $0.value == "before/* inside */after" }))
        try verifyCanary()
    }

    @Test("Deeply nested single quotes: '''''")
    func nestedQuotes() throws {
        let db = try makeSecurityTestDatabase()
        let values = ["'", "''", "'''", "''''", "'''''", "a'b'c'd'e"]
        for (i, val) in values.enumerated() {
            let obj = InjectionTarget(id: "q\(i)", value: val, score: i)
            try db.insert(obj)
        }

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == values.count)
        for (i, val) in values.enumerated() {
            #expect(results.contains(where: { $0.id == "q\(i)" && $0.value == val }))
        }
    }

    @Test("Backslash injection: \\' attempt to escape the escape")
    func backslashInjection() throws {
        let db = try makeSecurityTestDatabase()
        // In MySQL, \' would escape the quote. SQLite should NOT treat \ as escape.
        let payloads = [
            #"\'"#,
            #"\\'"#,
            #"\\\'"#,
            #"value\'; DROP TABLE Canary;--"#,
        ]
        let verifyCanary = try plantCanary(in: db)

        for (i, payload) in payloads.enumerated() {
            try db.insert(InjectionTarget(id: "bs\(i)", value: payload, score: i))
        }

        let results = try db.getAll(InjectionTarget.self)
        for (i, payload) in payloads.enumerated() {
            #expect(results.contains(where: { $0.id == "bs\(i)" && $0.value == payload }))
        }
        try verifyCanary()
    }

    @Test("Injection via delete: primary key with SQL in it")
    func injectionViaDelete() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let malicious = InjectionTarget(
            id: "' OR 1=1;--",
            value: "should only delete this one",
            score: 0
        )
        let innocent = InjectionTarget(id: "innocent", value: "safe", score: 1)
        try db.insert(malicious)
        try db.insert(innocent)

        try db.delete(malicious)

        let results = try db.getAll(InjectionTarget.self)
        // The innocent row must survive — the malicious PK should not become WHERE true
        #expect(results.contains(innocent))
        try verifyCanary()
    }

    @Test("Injection via update: primary key with SQL")
    func injectionViaUpdate() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let safe = InjectionTarget(id: "safe", value: "original", score: 10)
        try db.insert(safe)

        var malicious = InjectionTarget(id: "' OR 1=1;--", value: "attack", score: 0)
        try db.insert(malicious)

        malicious.value = "updated-attack"
        try db.update(malicious)

        // "safe" should be untouched
        let results = try db.getAll(InjectionTarget.self)
        #expect(results.contains(where: { $0.id == "safe" && $0.value == "original" }))
        try verifyCanary()
    }
}

// MARK: - NULL Byte and Control Character Injection

@Suite("NULL Byte & Control Character Injection")
struct NullByteInjectionTests {

    @Test("String with embedded NULL byte")
    func nullByteInString() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        // A NULL byte could truncate SQL at the C layer
        let payload = "before\0'; DROP TABLE Canary;--"
        let obj = InjectionTarget(id: "null-byte", value: payload, score: 0)
        // This might fail on insert (best case) or silently truncate.
        // Either way, Canary must survive.
        do {
            try db.insert(obj)
        } catch {
            // Acceptable — rejecting the input is safe behavior
        }
        try verifyCanary()
    }

    @Test("Primary key with embedded NULL byte")
    func nullByteInPrimaryKey() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let payload = "key\0'; DROP TABLE Canary;--"
        let obj = InjectionTarget(id: payload, value: "test", score: 0)
        do {
            try db.insert(obj)
        } catch {
            // Acceptable
        }
        try verifyCanary()
    }

    @Test("Tab, newline, carriage return in strings")
    func controlCharactersInStrings() throws {
        let db = try makeSecurityTestDatabase()
        let payloads = [
            "line1\nline2",
            "col1\tcol2",
            "return\rhere",
            "all\t\n\rtogether",
            "form\u{0C}feed",
            "bell\u{07}ring",
        ]

        for (i, payload) in payloads.enumerated() {
            try db.insert(InjectionTarget(id: "ctrl\(i)", value: payload, score: i))
        }

        let results = try db.getAll(InjectionTarget.self)
        for (i, payload) in payloads.enumerated() {
            #expect(results.contains(where: { $0.id == "ctrl\(i)" && $0.value == payload }))
        }
    }
}

// MARK: - Unicode Attack Vectors

@Suite("Unicode Attack Vectors")
struct UnicodeInjectionTests {

    @Test("Emoji in string values and primary keys")
    func emojiStrings() throws {
        let db = try makeSecurityTestDatabase()
        let obj = InjectionTarget(id: "🔥💀🐍", value: "emoji 🎉 value", score: 42)
        try db.insert(obj)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.id == "🔥💀🐍")
        #expect(results.first?.value == "emoji 🎉 value")
    }

    @Test("Zero-width characters (ZWJ, ZWNJ, ZWSP)")
    func zeroWidthCharacters() throws {
        let db = try makeSecurityTestDatabase()
        let zwj = "\u{200D}"  // Zero Width Joiner
        let zwnj = "\u{200C}"  // Zero Width Non-Joiner
        let zwsp = "\u{200B}"  // Zero Width Space

        let obj = InjectionTarget(id: "zw\(zwj)test", value: "a\(zwnj)b\(zwsp)c", score: 0)
        try db.insert(obj)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.id == "zw\(zwj)test")
        #expect(results.first?.value == "a\(zwnj)b\(zwsp)c")
    }

    @Test("RTL override characters")
    func rtlOverride() throws {
        let db = try makeSecurityTestDatabase()
        let rlo = "\u{202E}"  // Right-to-Left Override
        let lro = "\u{202D}"  // Left-to-Right Override

        let obj = InjectionTarget(id: "rtl", value: "\(rlo)Reversed\(lro)Normal", score: 0)
        try db.insert(obj)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.value == "\(rlo)Reversed\(lro)Normal")
    }

    @Test("Homoglyph attack: Cyrillic 'а' vs Latin 'a'")
    func homoglyphAttack() throws {
        let db = try makeSecurityTestDatabase()
        let latin = InjectionTarget(id: "a-latin", value: "latin a", score: 1)
        let cyrillic = InjectionTarget(id: "\u{0430}-cyrillic", value: "cyrillic а", score: 2)
        try db.insert(latin)
        try db.insert(cyrillic)

        let results = try db.getAll(InjectionTarget.self)
        // Both should coexist as distinct rows
        #expect(results.count == 2)
    }

    @Test("Astral plane characters (supplementary Unicode)")
    func astralPlaneCharacters() throws {
        let db = try makeSecurityTestDatabase()
        // Mathematical Bold A (U+1D400), Musical Symbol G Clef (U+1D11E)
        let obj = InjectionTarget(id: "astral", value: "𝐀 𝄞", score: 0)
        try db.insert(obj)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first?.value == "𝐀 𝄞")
    }

    @Test("Unicode normalization: é (composed) vs é (decomposed)")
    func unicodeNormalization() throws {
        let db = try makeSecurityTestDatabase()
        let composed = "caf\u{00E9}"  // é as single code point
        let decomposed = "caf\u{0065}\u{0301}"  // e + combining acute

        let obj1 = InjectionTarget(id: composed, value: "composed", score: 1)
        // Depending on normalization, these may or may not collide.
        // The library should at minimum not crash.
        try db.insert(obj1)
        do {
            try db.insert(InjectionTarget(id: decomposed, value: "decomposed", score: 2))
            // If they're different keys, both got inserted — fine
            let results = try db.getAll(InjectionTarget.self)
            #expect(results.count >= 1)
        } catch {
            // If they collide (same key), that's also an acceptable outcome
            let results = try db.getAll(InjectionTarget.self)
            #expect(results.count == 1)
        }
    }

    @Test("Extremely long Unicode string (10,000 emoji)")
    func longUnicodeString() throws {
        let db = try makeSecurityTestDatabase()
        let longString = String(repeating: "🔥", count: 10_000)
        let obj = InjectionTarget(id: "long-emoji", value: longString, score: 0)
        try db.insert(obj)

        let result = try #require(try db.getAll(InjectionTarget.self).first)
        #expect(result.value == longString)
    }
}

// MARK: - Numeric Boundary Attacks

@Suite("Numeric Boundary Attacks")
struct NumericBoundaryTests {

    @Test("Double.nan is rejected — nan is not valid SQL")
    func nanDouble() throws {
        let db = try makeSecurityTestDatabase()
        let obj = FloatTarget(id: "nan", doubleVal: .nan, floatVal: .nan)
        // NaN serializes to "nan" which is not valid SQL — the library should reject it
        #expect(throws: (any Error).self) {
            try db.insert(obj)
        }
    }

    @Test("Double.infinity is rejected — inf is not valid SQL")
    func infinityDouble() throws {
        let db = try makeSecurityTestDatabase()
        let pos = FloatTarget(id: "pos-inf", doubleVal: .infinity, floatVal: .infinity)
        // Infinity serializes to "inf" which is not valid SQL — the library should reject it
        #expect(throws: (any Error).self) {
            try db.insert(pos)
        }
        let neg = FloatTarget(id: "neg-inf", doubleVal: -.infinity, floatVal: -.infinity)
        #expect(throws: (any Error).self) {
            try db.insert(neg)
        }
    }

    @Test("Subnormal / denormalized floating-point values")
    func subnormalFloats() throws {
        let db = try makeSecurityTestDatabase()
        let obj = FloatTarget(
            id: "subnormal",
            doubleVal: Double.leastNonzeroMagnitude,
            floatVal: Float.leastNonzeroMagnitude
        )
        try db.insert(obj)

        let result = try #require(try db.getAll(FloatTarget.self).first)
        // At minimum, the value should not be exactly 0 (it's subnormal, not zero)
        #expect(result.doubleVal != 0 || result.doubleVal == Double.leastNonzeroMagnitude)
    }

    @Test("Negative zero round-trip")
    func negativeZero() throws {
        let db = try makeSecurityTestDatabase()
        let obj = FloatTarget(id: "neg-zero", doubleVal: -0.0, floatVal: -0.0)
        try db.insert(obj)

        let result = try #require(try db.getAll(FloatTarget.self).first)
        // -0.0 == 0.0 in IEEE 754, so this should at least not crash
        #expect(result.doubleVal == 0.0)
    }

    @Test("Max/min integer boundaries in score field")
    func integerBoundaries() throws {
        let db = try makeSecurityTestDatabase()
        let max = InjectionTarget(id: "max-int", value: "max", score: Int.max)
        let min = InjectionTarget(id: "min-int", value: "min", score: Int.min)
        try db.insert(max)
        try db.insert(min)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.first(where: { $0.id == "max-int" })?.score == Int.max)
        #expect(results.first(where: { $0.id == "min-int" })?.score == Int.min)
    }
}

// MARK: - Primary Key Abuse

@Suite("Primary Key Abuse")
struct PrimaryKeyAbuseTests {

    @Test("Empty string as primary key")
    func emptyPrimaryKey() throws {
        let db = try makeSecurityTestDatabase()
        let obj = InjectionTarget(id: "", value: "empty-pk", score: 0)
        try db.insert(obj)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == 1)
        #expect(results.first?.id == "")
    }

    @Test("Whitespace-only primary key")
    func whitespacePrimaryKey() throws {
        let db = try makeSecurityTestDatabase()
        let spaces = InjectionTarget(id: "   ", value: "spaces", score: 0)
        let tabs = InjectionTarget(id: "\t\t", value: "tabs", score: 1)
        let newlines = InjectionTarget(id: "\n\n", value: "newlines", score: 2)
        try db.insert(spaces)
        try db.insert(tabs)
        try db.insert(newlines)

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == 3)
    }

    @Test("Primary key containing SQL keywords")
    func sqlKeywordsAsPrimaryKey() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let keywords = [
            "SELECT", "DROP", "DELETE", "INSERT", "UPDATE",
            "CREATE", "ALTER", "TABLE", "WHERE", "FROM",
            "JOIN", "NULL", "TRUE", "FALSE", "AND", "OR",
        ]
        for keyword in keywords {
            try db.insert(InjectionTarget(id: keyword, value: "keyword-test", score: 0))
        }

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == keywords.count)
        for keyword in keywords {
            #expect(results.contains(where: { $0.id == keyword }))
        }
        try verifyCanary()
    }

    @Test("Primary key with parentheses and operators")
    func operatorsInPrimaryKey() throws {
        let db = try makeSecurityTestDatabase()
        let payloads = [
            "(1=1)", "1; --", "1 UNION ALL SELECT 1",
            "' AND ''='", ") OR (1=1", "/**/ OR 1=1",
        ]
        for (i, payload) in payloads.enumerated() {
            try db.insert(InjectionTarget(id: "op\(i)-\(payload)", value: "test", score: i))
        }

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == payloads.count)
    }
}

// MARK: - Optional Field Injection

@Suite("Optional Field Injection")
struct OptionalFieldInjectionTests {

    @Test("SQL injection in optional string field — canary survives")
    func injectionInOptionalField() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let malicious = OptionalInjectionTarget(
            id: "opt-evil",
            notes: "'; DROP TABLE Canary;--"
        )
        // Whether insert succeeds or fails, the canary must survive
        do {
            try db.insert(malicious)
        } catch {
            // Acceptable — some optional column handling may reject
        }
        try verifyCanary()
    }

    @Test("Transition from non-nil injection payload to different payload — canary survives")
    func payloadToPayloadTransition() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        var obj = OptionalInjectionTarget(id: "evil-swap", notes: "' OR 1=1--")
        try db.insert(obj)

        obj.notes = "'; DROP TABLE Canary;--"
        do {
            try db.update(obj)
        } catch {
            // Acceptable — optional field handling limitation
        }

        // The critical assertion: canary must survive regardless
        try verifyCanary()
    }

    @Test("Nil optional insert then update — canary survives")
    func nilToInjectionPayload() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        // Inserting nil first may not create the column;
        // the update may then fail. Either way, canary must survive.
        var obj = OptionalInjectionTarget(id: "nil-to-evil", notes: nil)
        do {
            try db.insert(obj)
            obj.notes = "' OR '1'='1'; DROP TABLE Canary;--"
            try db.update(obj)
        } catch {
            // Acceptable — optional column schema limitation
        }
        try verifyCanary()
    }

    @Test("Payload to nil transition — canary survives")
    func injectionPayloadToNil() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        var obj = OptionalInjectionTarget(id: "evil-to-nil", notes: "'; DROP TABLE Canary;--")
        try db.insert(obj)

        // Update to nil triggers delete + re-insert. The re-insert may exclude
        // the notes column, causing a constraint error. Either way, canary survives.
        obj.notes = nil
        do {
            try db.update(obj)
        } catch {
            // Acceptable — NOT NULL constraint from original schema
        }
        try verifyCanary()
    }
}

// MARK: - Raw Filter & Sort String Injection

@Suite("Raw Filter/Sort String Injection")
struct RawFilterSortInjectionTests {

    @Test("Malicious filteredBy string: always-true condition")
    func alwaysTrueFilter() throws {
        let db = try makeSecurityTestDatabase()
        let a = InjectionTarget(id: "a", value: "Alice", score: 100)
        let b = InjectionTarget(id: "b", value: "Bob", score: 50)
        try db.insert(a)
        try db.insert(b)

        // If raw SQL passes through, "1=1" returns all rows
        let results = try db.getAll(
            InjectionTarget.self,
            sortedBy: nil,
            filteredBy: "1=1"
        )
        // This is expected to work since the API accepts raw SQL.
        // The concern is whether it can be escalated to destructive operations.
        #expect(results.count == 2)
    }

    @Test("Destructive filteredBy via subquery")
    func destructiveSubqueryFilter() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)
        try db.insert(InjectionTarget(id: "x", value: "test", score: 0))

        // Attempt to use a subquery to access other tables
        // sqlite3_prepare_v2 handles only one statement — this should not drop the table
        let maliciousFilter = "1=1; DROP TABLE Canary;--"
        do {
            _ = try db.getAll(
                InjectionTarget.self,
                sortedBy: nil,
                filteredBy: maliciousFilter
            )
        } catch {
            // Error is acceptable — rejecting is safe
        }
        try verifyCanary()
    }

    @Test("Destructive sortedBy string")
    func destructiveSortString() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)
        try db.insert(InjectionTarget(id: "x", value: "test", score: 0))

        let maliciousSort = "id; DROP TABLE Canary;--"
        do {
            _ = try db.getAll(
                InjectionTarget.self,
                sortedBy: maliciousSort,
                filteredBy: nil
            )
        } catch {
            // Error is acceptable
        }
        try verifyCanary()
    }

    @Test("UNION injection via filteredBy to exfiltrate sqlite_master")
    func unionInjectionViaFilter() throws {
        let db = try makeSecurityTestDatabase()
        try db.insert(InjectionTarget(id: "x", value: "test", score: 0))

        // Attempt UNION-based data exfiltration
        let maliciousFilter = "1=0 UNION SELECT name, type, sql, 0 FROM sqlite_master"
        do {
            let results: [InjectionTarget] = try db.getAll(
                InjectionTarget.self,
                sortedBy: nil,
                filteredBy: maliciousFilter
            )
            // If this succeeds, ensure the results don't leak schema info as InjectionTarget objects.
            // Due to type-safe decoding, any "leaked" data is constrained to the Object's schema.
            for result in results {
                // None of these should contain table creation SQL
                #expect(!result.value.contains("CREATE TABLE"))
            }
        } catch {
            // Error is acceptable — query likely fails due to column mismatch
        }
    }

    @Test("Blind SQL injection via filteredBy: timing/boolean-based")
    func blindSQLInjectionViaFilter() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)
        try db.insert(InjectionTarget(id: "secret", value: "s3cret_data", score: 42))

        // Boolean-based blind injection: see if we can infer data through true/false filters
        let probeTrue = "id = 'secret' AND length(value) > 5"
        let probeFalse = "id = 'secret' AND length(value) > 50"

        let trueResults = try db.getAll(
            InjectionTarget.self,
            sortedBy: nil,
            filteredBy: probeTrue
        )
        let falseResults = try db.getAll(
            InjectionTarget.self,
            sortedBy: nil,
            filteredBy: probeFalse
        )

        // These technically work with raw SQL — this documents that the raw string API
        // is intentionally powerful. Security boundary is at the app layer, not here.
        // We just verify nothing destructive happened.
        #expect(trueResults.count <= 1)
        #expect(falseResults.isEmpty)
        try verifyCanary()
    }
}

// MARK: - Massive Payload / Resource Exhaustion

@Suite("Resource Exhaustion & Boundary Payloads")
struct ResourceExhaustionTests {

    @Test("Extremely long SQL injection payload (100KB)")
    func veryLongInjectionPayload() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let longPayload = String(repeating: "'; DROP TABLE Canary;--", count: 5_000)
        let obj = InjectionTarget(id: "long-payload", value: longPayload, score: 0)
        try db.insert(obj)

        let result = try #require(try db.getAll(InjectionTarget.self).first)
        #expect(result.value == longPayload)
        try verifyCanary()
    }

    @Test("String of 10,000 single quotes")
    func manyQuotes() throws {
        let db = try makeSecurityTestDatabase()
        let quotes = String(repeating: "'", count: 10_000)
        let obj = InjectionTarget(id: "quotes", value: quotes, score: 0)
        try db.insert(obj)

        let result = try #require(try db.getAll(InjectionTarget.self).first)
        #expect(result.value == quotes)
    }

    @Test("Rapid insert/delete cycle (1000 objects)")
    func rapidInsertDeleteCycle() throws {
        let db = try makeSecurityTestDatabase()
        for i in 0..<1000 {
            let obj = InjectionTarget(id: "cycle-\(i)", value: "val", score: i)
            try db.insert(obj)
            try db.delete(obj)
        }
        let results = try db.getAll(InjectionTarget.self)
        #expect(results.isEmpty)
    }

    @Test("Value containing only whitespace and special chars")
    func whitespaceAndSpecialValues() throws {
        let db = try makeSecurityTestDatabase()
        let values = [
            "", " ", "  ", "\t", "\n", "\r\n",
            "   \t\n\r   ", String(repeating: " ", count: 1000),
        ]
        for (i, val) in values.enumerated() {
            try db.insert(InjectionTarget(id: "ws\(i)", value: val, score: i))
        }

        let results = try db.getAll(InjectionTarget.self)
        #expect(results.count == values.count)
    }
}

// MARK: - Encoding Representation Attacks

@Suite("Encoding Representation Attacks")
struct EncodingRepresentationTests {

    @Test("String 'NULL' in optional field — documents encoding ambiguity")
    func stringNullInOptionalField() throws {
        let db = try makeSecurityTestDatabase()
        // Insert with non-nil value "NULL" (the string)
        let stringNull = OptionalInjectionTarget(id: "string-null", notes: "NULL")
        try db.insert(stringNull)

        let results = try db.getAll(OptionalInjectionTarget.self)
        let sn = results.first(where: { $0.id == "string-null" })

        // KNOWN LIMITATION: The library uses the literal string "NULL" for nil,
        // so the string value "NULL" is indistinguishable from actual nil on decode.
        // This documents a real encoding ambiguity — the string "NULL" is lost.
        #expect(
            sn?.notes == nil,
            """
            Known limitation: String 'NULL' is conflated with SQL NULL \
            because the encoder uses the literal 'NULL' for nil values.
            """)
    }

    @Test("Actual NULL insert after non-nil — canary survives")
    func actualNullAfterNonNil() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        // First insert creates the column as NOT NULL
        try db.insert(OptionalInjectionTarget(id: "non-nil", notes: "value"))

        // Inserting nil may fail due to NOT NULL constraint — that's a known limitation
        do {
            try db.insert(OptionalInjectionTarget(id: "actual-null", notes: nil))
        } catch {
            // Acceptable — NOT NULL constraint from schema created by first insert
        }
        try verifyCanary()
    }

    @Test("String 'true' / 'false' vs boolean values")
    func stringVsBooleanConfusion() throws {
        let db = try makeSecurityTestDatabase()
        // Insert objects with string values that look like booleans
        let obj = InjectionTarget(id: "bool-str", value: "true", score: 0)
        try db.insert(obj)

        let result = try #require(try db.getAll(InjectionTarget.self).first)
        #expect(result.value == "true")
    }

    @Test("Value 'databaseRepresentation' of numbers in string fields")
    func numericStrings() throws {
        let db = try makeSecurityTestDatabase()
        let numericStrings = [
            "0", "-1", "3.14", "1e308", "-1e308",
            "NaN", "Infinity", "-Infinity",
            "9999999999999999999999999999",
        ]
        for (i, val) in numericStrings.enumerated() {
            try db.insert(InjectionTarget(id: "num\(i)", value: val, score: i))
        }

        let results = try db.getAll(InjectionTarget.self)
        for (i, val) in numericStrings.enumerated() {
            #expect(results.first(where: { $0.id == "num\(i)" })?.value == val)
        }
    }
}

// MARK: - Cross-Table Contamination

@Suite("Cross-Table Contamination")
struct CrossTableTests {

    @Test("Injection in one table does not affect another")
    func crossTableIsolation() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        // Fill InjectionTarget with malicious data
        let payloads = [
            "'; DROP TABLE Canary;--",
            "'; DELETE FROM Canary WHERE 1=1;--",
            "'; UPDATE Canary SET alive=0 WHERE 1=1;--",
            "'; INSERT INTO Canary VALUES ('fake', 0);--",
        ]
        for (i, payload) in payloads.enumerated() {
            try db.insert(InjectionTarget(id: "cross\(i)", value: payload, score: i))
        }

        try verifyCanary()
        let injectionResults = try db.getAll(InjectionTarget.self)
        #expect(injectionResults.count == payloads.count)
    }

    @Test("Drop one table does not affect sibling tables")
    func dropTableIsolation() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)
        try db.insert(InjectionTarget(id: "doomed", value: "gone", score: 0))

        try db.dropTable(InjectionTarget.self)

        try verifyCanary()
    }
}

// MARK: - Composed Object Injection

@Suite("Composed Object Injection via Foreign Keys")
struct ComposedObjectInjectionTests {

    @Test("Inner object primary key with SQL injection payload")
    func innerObjectInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        // The inner TestObject's string PK contains an injection attempt
        let inner = TestObject(
            string: "'; DROP TABLE Canary;--",
            int: 0, int8: 0, int16: 0, int32: 0, int64: 0,
            uint: 0, uint8: 0, uint16: 0, uint32: 0, uint64: 0,
            double: 0, float: 0, cgFloat: 0,
            intOptional: nil
        )
        let composed = ComposedTestObject(testObject: inner)
        try db.insert(composed)

        let results = try db.getAll(ComposedTestObject.self)
        #expect(results.count == 1)
        #expect(results.first?.testObject.string == "'; DROP TABLE Canary;--")
        try verifyCanary()
    }
}

// MARK: - Date Injection

@Suite("Date Value Injection")
struct DateInjectionTests {

    @Model
    struct DateTarget: Object, Equatable {
        static var primaryKey: CodingKey { CodingKeys.id }
        var id: String
        var timestamp: Date
    }

    @Test("Date insertion — format is not SQL-safe without quoting")
    func dateRoundTrip() throws {
        let db = try makeSecurityTestDatabase()
        let date = Date(timeIntervalSince1970: 0)  // 1970-01-01
        let obj = DateTarget(id: "epoch", timestamp: date)
        // Date.databaseRepresentation returns "yyyy-MM-dd HH:mm:ss" without quotes,
        // which causes an SQL syntax error. This documents the limitation.
        #expect(throws: (any Error).self) {
            try db.insert(obj)
        }
    }

    @Test("Distant past and future dates — rejected safely")
    func extremeDates() throws {
        let db = try makeSecurityTestDatabase()
        let past = DateTarget(id: "past", timestamp: .distantPast)
        let future = DateTarget(id: "future", timestamp: .distantFuture)
        // Date formatting produces unquoted strings, causing SQL syntax errors
        #expect(throws: (any Error).self) {
            try db.insert(past)
        }
        #expect(throws: (any Error).self) {
            try db.insert(future)
        }
    }
}

// MARK: - Comprehensive Injection Payload Battery

@Suite("Injection Payload Battery")
struct InjectionPayloadBatteryTests {

    /// A broad collection of known SQL injection payloads. Every one must either:
    /// 1. Be stored and retrieved verbatim, or
    /// 2. Cause an error (safe rejection).
    /// The Canary table must NEVER be destroyed.
    @Test("50+ known SQL injection payloads survive round-trip without side effects")
    func comprehensivePayloadBattery() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let payloads: [String] = [
            // Classic breakouts
            "' OR '1'='1",
            "' OR '1'='1'--",
            "' OR '1'='1'/*",
            "' OR 1=1--",
            "') OR ('1'='1",
            "') OR ('1'='1'--",
            "1' OR '1' = '1'",

            // DROP TABLE variants
            "'; DROP TABLE Canary;--",
            "'; DROP TABLE Canary;/*",
            "'; DROP TABLE IF EXISTS Canary;--",
            "' ; DROP TABLE Canary ; --",

            // DELETE/UPDATE attacks
            "'; DELETE FROM Canary;--",
            "'; DELETE FROM Canary WHERE 1=1;--",
            "'; UPDATE Canary SET alive=0;--",

            // INSERT attacks
            "'; INSERT INTO Canary VALUES('injected', 0);--",

            // UNION attacks
            "' UNION SELECT * FROM Canary--",
            "' UNION ALL SELECT NULL, NULL--",
            "' UNION SELECT name FROM sqlite_master--",

            // Subquery attacks
            "' AND (SELECT COUNT(*) FROM Canary) > 0--",
            "' OR EXISTS(SELECT 1 FROM Canary)--",

            // Comment attacks
            "admin'--",
            "admin'/*",
            "1--",
            "1/*",

            // Multi-line attacks
            "'\n'; DROP TABLE Canary;\n--",
            "'\r\n'; DROP TABLE Canary;\r\n--",

            // Hex / char encoding
            "' OR CHAR(49)=CHAR(49)--",
            "' OR X'31'=X'31'--",

            // LIKE wildcards
            "' OR value LIKE '%'--",
            "%", "_", "%_%",

            // SQLite-specific
            "' OR typeof(id)='text'--",
            "'; ATTACH DATABASE ':memory:' AS evil;--",
            "'; DETACH DATABASE main;--",
            "'; PRAGMA table_info(Canary);--",
            "'; VACUUM;--",

            // Double encoding
            "''",
            "''''",
            "''''''",

            // Nested injection
            "' AND '1'='1' AND '1'='1",
            "' OR '' = '",

            // Backslash tricks (MySQL-style, shouldn't work in SQLite)
            #"\'"#,
            #"\\'"#,
            #"\\\'"#,

            // NULL and special values
            "NULL",
            "null",
            "None",
            "nil",
            "undefined",
            "NaN",
            "Infinity",
        ]

        for (i, payload) in payloads.enumerated() {
            let obj = InjectionTarget(id: "battery-\(i)", value: payload, score: i)
            do {
                try db.insert(obj)
            } catch {
                // Safe rejection is acceptable
                continue
            }
        }

        // Verify canary survived ALL payloads
        try verifyCanary()

        let results = try db.getAll(InjectionTarget.self)
        // Every successfully inserted payload should be retrieved verbatim
        for result in results {
            let index = Int(result.id.replacingOccurrences(of: "battery-", with: ""))!
            #expect(
                result.value == payloads[index],
                "Payload \(index) was mutated: expected \(payloads[index]), got \(result.value)")
        }
    }
}

// MARK: - Sift Predicate Type-Safety Verification

@Suite("Sift Predicate Type-Safety")
struct SiftPredicateTypeTests {

    @Test("Value with SQL in it used in equality predicate filter")
    func sqlInEqualityPredicateValue() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        let normal = InjectionTarget(id: "normal", value: "safe", score: 10)
        let evil = InjectionTarget(id: "evil", value: "'; DROP TABLE Canary;--", score: 20)
        try db.insert(normal)
        try db.insert(evil)

        // The Sift predicate should escape the value through databaseRepresentation
        let results = try db.getAll(
            InjectionTarget.self,
            filteredBy: \InjectionTarget.value == "'; DROP TABLE Canary;--"
        )
        #expect(results.count == 1)
        #expect(results.first?.id == "evil")
        try verifyCanary()
    }

    @Test("Predicate with single-quote in comparison value")
    func singleQuoteInPredicateValue() throws {
        let db = try makeSecurityTestDatabase()
        let obj = InjectionTarget(id: "o'connor", value: "Irish", score: 0)
        try db.insert(obj)

        let results = try db.getAll(
            InjectionTarget.self,
            filteredBy: \InjectionTarget.id == "o'connor"
        )
        #expect(results.count == 1)
        #expect(results.first?.id == "o'connor")
    }

    @Test("AND/OR predicates with injection values")
    func compoundPredicateWithInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        try db.insert(InjectionTarget(id: "a", value: "' OR 1=1--", score: 1))
        try db.insert(InjectionTarget(id: "b", value: "clean", score: 2))

        let results = try db.getAll(
            InjectionTarget.self,
            filteredBy: \InjectionTarget.value == "' OR 1=1--" && \InjectionTarget.score == 1
        )
        #expect(results.count == 1)
        #expect(results.first?.id == "a")
        try verifyCanary()
    }

    @Test("NOT predicate with injection value")
    func notPredicateWithInjection() throws {
        let db = try makeSecurityTestDatabase()
        let verifyCanary = try plantCanary(in: db)

        try db.insert(InjectionTarget(id: "keep", value: "safe", score: 1))
        try db.insert(InjectionTarget(id: "filter", value: "'; DROP TABLE Canary;--", score: 2))

        let results = try db.getAll(
            InjectionTarget.self,
            filteredBy: !(\InjectionTarget.value == "'; DROP TABLE Canary;--")
        )
        #expect(results.count == 1)
        #expect(results.first?.id == "keep")
        try verifyCanary()
    }
}
