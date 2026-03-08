![CodableDB](https://user-images.githubusercontent.com/15239005/218556442-db228d5d-0ed7-4932-8ec8-1b56e83a124d.png)

# CodableDB

A lightweight, type-safe Swift library that persists any `Codable` struct directly into a SQLite database — no schema definitions, no boilerplate, no ORM overhead. Tables are created automatically from your types.

## Features

- **Zero-config persistence** — add `@Model`, conform to `Object`, and start storing data immediately.
- **Type-safe queries** — filter and sort with Swift key-path expressions powered by [Sift](https://github.com/pauljohanneskraft/sift).
- **Automatic table creation** — tables and columns are derived at runtime from your `Codable` conformance.
- **Nested object support** — properties that are themselves `Object` types are stored in their own tables and linked by primary key.
- **All Swift primitives** — `String`, `Bool`, `Int`, `Int8`–`Int64`, `UInt8`–`UInt64`, `Double`, `Float`, `CGFloat`, `Date`, and optionals.
- **`@Model` macro** — auto-generates the key-path-to-column mapping so you never write boilerplate.
- **`@Column` property wrapper** — customize the column name for any property.
- **SQL injection protection** — string values are escaped via single-quote doubling; `sqlite3_prepare_v2` blocks stacked-query attacks.

## Requirements

- Swift 6.2+
- macOS / iOS / any Apple platform with SQLite3

## Installation

Add CodableDB to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pauljohanneskraft/CodableDB.git", branch: "main"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CodableDB"]
    ),
]
```

## Getting Started

### 1. Define a model

Annotate your struct with `@Model` and conform to `Object`. The only
requirement is a `primaryKey`:

```swift
import CodableDB

@Model
struct Task: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.id }

    var id: String
    var title: String
    var priority: Int
    var isCompleted: Bool
}
```

The macro generates `KeyPathCodable` conformance automatically — no manual
column mappings needed.

### 2. Open a database

```swift
let dbPath = URL.documentsDirectory.appendingPathComponent("app.sqlite")
let db = try Database(filePath: dbPath)
```

### 3. Insert, query, update, delete

```swift
// Insert
let task = Task(id: "1", title: "Buy groceries", priority: 2, isCompleted: false)
try db.insert(task)

// Get all
let tasks = try db.getAll(Task.self)

// Update (deletes + re-inserts by primary key)
var updated = task
updated.isCompleted = true
try db.update(updated)

// Delete
try db.delete(task)

// Count
let total = try db.count(Task.self)

// Drop the entire table
try db.dropTable(Task.self)
```

### 4. Filter and sort with Sift

CodableDB integrates with [Sift](https://github.com/pauljohanneskraft/sift) for type-safe, key-path-based predicates and orderings that compile down to SQL:

```swift
import Sift

// Filter
let urgent = try db.getAll(
    Task.self,
    filteredBy: \Task.priority > 3 && \Task.isCompleted == false
)

// Sort
let sorted = try db.getAll(
    Task.self,
    sortedBy: Descending(\Task.priority)
)

// Combine both
let results = try db.getAll(
    Task.self,
    sortedBy: Ascending(\Task.title),
    filteredBy: \Task.isCompleted == false
)
```

Supported operators: `==`, `!=`, `<`, `<=`, `>`, `>=`, `&&`, `||`.

### 5. Custom column names with `@Column`

Use the `@Column` property wrapper to map a Swift property to a specific column name.
The `@Model` macro reads `@Column` attributes automatically.
Provide matching `CodingKeys` so the encoder uses the same name:

```swift
@Model
struct User: Object {
    static var primaryKey: CodingKey { CodingKeys.id }

    @Column("user_id") var id: String
    @Column("full_name") var name: String
    var age: Int

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name = "full_name"
        case age
    }
}
```

### 6. Nested objects

Properties that conform to `Object` are stored in their own table and referenced by primary key:

```swift
@Model
struct Author: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.name }
    var name: String
}

@Model
struct Book: Object, Equatable {
    static var primaryKey: CodingKey { CodingKeys.title }
    var title: String
    var author: Author  // stored in the "Author" table, linked by primary key
}

try db.insert(Book(title: "1984", author: Author(name: "Orwell")))
let books = try db.getAll(Book.self) // author is resolved automatically
```

## Security

CodableDB includes a comprehensive security test suite (98 tests across 26 suites) that validates resilience against SQL injection and adversarial inputs. Key protections:

- **Single-quote escaping** — all `String` values go through `replacingOccurrences(of: "'", with: "''")`  before being interpolated into SQL, preventing classic `' OR '1'='1` breakouts.
- **Single-statement execution** — `sqlite3_prepare_v2` only compiles one SQL statement at a time, blocking stacked-query attacks like `'; DROP TABLE users;--`.
- **Type-safe Sift predicates** — when using the key-path predicate API (e.g. `\Task.name == value`), values pass through `databaseRepresentation` which applies proper escaping. This is the recommended API for user-facing queries.
- **Non-finite float rejection** — `Double.nan`, `Double.infinity`, and their `Float` equivalents are rejected at encode time, preventing invalid SQL literals from reaching the database.
- **Correct optional round-tripping** — `nil` values are stored as SQL `NULL` and non-nil optionals use nullable column types, so `nil` ↔ non-nil transitions and the string `"NULL"` all round-trip correctly.

The test suite covers: classic SQL injection (OR breakouts, DROP TABLE, UNION SELECT, stacked queries), NULL byte injection, control characters, Unicode edge cases (emoji, zero-width characters, RTL overrides, homoglyphs, astral plane), numeric boundaries, primary key abuse, composed/nested object injection, cross-table contamination, resource exhaustion (100 KB payloads, 10k quotes, 1000-cycle stress), and a battery of 50+ known injection patterns.

## Known Limitations

### 1. Raw `filteredBy`/`sortedBy` strings accept arbitrary SQL

The `getAll(_:sortedBy:filteredBy:)` overload that takes `String?` parameters passes the filter and sort clauses directly into the SQL statement without validation. This is by design for power users, but means the caller is responsible for sanitizing any user-provided input passed through these parameters. **Recommendation:** always use the type-safe Sift predicate API (`\Type.field == value`) for any query involving untrusted input. Reserve the raw string API for internal or developer-controlled queries.

## License

See [LICENSE](LICENSE) for details.
