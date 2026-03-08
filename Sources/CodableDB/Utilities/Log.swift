/// Logs a debug message prefixed with the module name.
func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
        print(
            "[CodableDB]: " + items.map { "\($0)" }.joined(separator: separator),
            terminator: terminator)
    #endif
}
