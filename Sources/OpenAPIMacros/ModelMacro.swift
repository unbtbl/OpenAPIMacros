import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ModelMacro {}

extension ModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let cases = declaration.memberBlock.members.compactMap { member -> String? in
            // is a property
            guard
                let propertyName = member.decl.as(VariableDeclSyntax.self)?.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                return nil
            }

            return """
      case \\Self.\(propertyName):
          return CodingKeys.\(propertyName)
      """
        }

        let addResolveField: DeclSyntax = """
    public static func codingKey<T>(forKeyPath keyPath: KeyPath<Self, T>) -> CodingKey {
      switch keyPath {
      \(raw: cases.joined(separator: "\n"))
      default:
        fatalError("Unknown KeyPath, likely not a stored property")
      }
    }
    """

        return [
            addResolveField
        ]
    }
}

extension ModelMacro: ConformanceMacro {
    public static func expansion<Declaration, Context>(
        of node: AttributeSyntax,
        providingConformancesOf declaration: Declaration,
        in context: Context
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        return [ ("ModelProtocol", nil) ]
    }
}

@main
struct ModelPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ModelMacro.self,
        OpenAPIRouteMacro.self,
        OpenAPITypeMacro.self,
        URLMacro.self,
    ]
}
