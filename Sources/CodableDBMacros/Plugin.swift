import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CodableDBMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        CodableDBModelMacro.self,
    ]
}
