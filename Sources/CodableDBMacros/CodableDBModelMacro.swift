import SwiftSyntax
import SwiftSyntaxMacros

/// Generates `Object` and `KeyPathCodable` conformance with an auto-derived `columns` dictionary.
///
/// For each stored `var` property, the macro maps `\Self.propertyName` to its
/// SQL column name. If a property is annotated with `@Column("custom_name")`,
/// that custom name is used; otherwise the property name is used as-is.
public struct CodableDBModelMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro (generates the `columns` property)

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let entries = try columnEntries(from: declaration)
        guard !entries.isEmpty else { return [] }

        let mappings =
            entries
            .map { "\\.\($0.propertyName): \"\($0.columnName)\"" }
            .joined(separator: ", ")

        let decl: DeclSyntax = """
            static var columns: [PartialKeyPath<Self>: String] {
                [\(raw: mappings)]
            }
            """
        return [decl]
    }

    // MARK: - ExtensionMacro (adds Object & KeyPathCodable conformance)

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
            extension \(type.trimmed): Object, KeyPathCodable {}
            """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Helpers

    private struct ColumnEntry {
        let propertyName: String
        let columnName: String
    }

    private static func columnEntries(
        from declaration: some DeclGroupSyntax
    ) throws -> [ColumnEntry] {
        declaration.memberBlock.members.compactMap { member -> ColumnEntry? in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                variable.bindingSpecifier.tokenKind == .keyword(.var),
                !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
                let binding = variable.bindings.first,
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else {
                return nil
            }

            // Check for @Column("custom_name")
            let customName = variable.attributes.compactMap { attr -> String? in
                guard let attribute = attr.as(AttributeSyntax.self),
                    let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self),
                    identifier.name.text == "Column",
                    let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
                    let firstArg = arguments.first,
                    let literal = firstArg.expression.as(StringLiteralExprSyntax.self),
                    let segment = literal.segments.first?.as(StringSegmentSyntax.self)
                else {
                    return nil
                }
                return segment.content.text
            }.first

            return ColumnEntry(
                propertyName: name,
                columnName: customName ?? name
            )
        }
    }
}
