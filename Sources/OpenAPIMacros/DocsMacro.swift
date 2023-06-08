import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

extension String: Error {}

protocol OpenAPIDocsMacro: MemberMacro {}

public struct OpenAPIExampleMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Does nothing, used only to decorate members with data
        return []
    }
}

public struct OpenAPIRouteMacro: OpenAPIDocsMacro {
    public static func expansion<Declaration, Context>(of node: AttributeSyntax, providingMembersOf declaration: Declaration, in context: Context) throws -> [DeclSyntax] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        let docs = try docsExpansion(
            of: node,
            providingMembersOf: declaration,
            in: context
        )

        return [docs]
    }
}

private struct MissingDocsMessage: DiagnosticMessage {
    let message = "This property is undocumented"

    var diagnosticID: MessageID {
        .init(domain: "software.unbeatabele.model-macro", id: "undocumented")
    }

    var severity: DiagnosticSeverity { .warning }
}

public struct OpenAPITypeMacro: OpenAPIDocsMacro {
    public static func expansion<Declaration, Context>(of node: AttributeSyntax, providingMembersOf declaration: Declaration, in context: Context) throws -> [DeclSyntax] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        let docs = try docsExpansion(
            of: node,
            providingMembersOf: declaration,
            in: context
        )
        let codingKey = try codingKeyExpansion(
            of: node,
            providingMembersOf: declaration,
            in: context
        )
        let properties = try propertiesExpansion(
            of: node,
            providingMembersOf: declaration,
            in: context
        )
        let schema = try schemaExpansion(
            of: node,
            providingMembersOf: declaration,
            in: context
        )
        let examples = try examplesExpansion(
            of: node,
            providingMembersOf: declaration,
            in: context
        )

        return [
            docs,
            codingKey,
            properties,
            schema,
            examples,
        ]
    }

    static func propertiesExpansion<Declaration, Context>(of node: AttributeSyntax, providingMembersOf declaration: Declaration, in context: Context) throws -> DeclSyntax where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        let variables = declaration.memberBlock.members
        let pairs = variables.compactMap { variable -> String? in
            guard let variable = variable.decl.as(VariableDeclSyntax.self) else {
                return nil
            }

            // Don't require documentation for static properties
            if let modifiers = variable.modifiers {
                for modifier in modifiers {
                    if case .keyword(.static) = modifier.name.tokenKind {
                        return nil
                    }
                }
            }

            guard let identifier = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                return nil
            }

            let comments = variable.leadingTrivia.comments

            if comments.isEmpty {
                context.diagnose(.init(node: variable._syntaxNode, message: MissingDocsMessage()))
            }

            var string = "Self.codingKey(forKeyPath: \\.\(identifier)).stringValue: "
            string.append("#\"")
            string.append(comments.joined(separator: " "))
            string.append("\"#")
            return string
        }

        return """
        private static var properties: [String: String] {
            [
                \(raw: pairs.isEmpty ? ":" : pairs.joined(separator: ",\n"))
            ]
        }
        """
    }

    public static func examplesExpansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        let memberList = declaration.memberBlock.members

        let examples = memberList.compactMap({ member -> String? in
            // is a property
            guard
                let propertyName = member.decl.as(VariableDeclSyntax.self)?.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                return nil
            }

            // if it has a CodableKey macro on it
            guard let customKeyMacro = member.decl.as(VariableDeclSyntax.self)?.attributes?.first(where: { element in
                element.as(AttributeSyntax.self)?.attributeName.as(SimpleTypeIdentifierSyntax.self)?.description == "OpenAPIExample"
            }) else {
                return nil
            }

            // Uses the value in the Macro
            let customKeyValue = customKeyMacro.as(AttributeSyntax.self)!.argument!.as(TupleExprElementListSyntax.self)!.first!.expression

            return """
            \(customKeyValue): Self.\(propertyName)
            """
        })

        return """
        public static var examples: [String: Self] {
            [
                \(raw: examples.isEmpty ? ":" : examples.joined(separator: ",\n"))
            ]
        }
        """
    }

    public static func schemaExpansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        let variables = declaration.memberBlock.members
        let pairs = variables.compactMap { variable -> String? in
            guard let variable = variable.decl.as(VariableDeclSyntax.self) else {
                return nil
            }

            // Skip static properties
            if let modifiers = variable.modifiers {
                for modifier in modifiers {
                    if case .keyword(.static) = modifier.name.tokenKind {
                        return nil
                    }
                }
            }

            guard
                let name = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let typeIdentifier = variable.bindings.first?.typeAnnotation?.type
            else {
                return nil
            }

            let required = "true"

            return """
            makeProperty(
                key: Self.codingKey(forKeyPath: \\.\(name)).stringValue,
                required: \(required),
                type: \(typeIdentifier.description).self
            )
            """
        }

        return """
        public static func schema(description: String?, required: Bool) -> JSONSchema {
            var properties = OrderedDictionary<String, JSONSchema>()
            func makeProperty<Schema: OpenAPISchema>(key: String, required: Bool, type: Schema.Type) {
                properties[key] = Schema.schema(
                    description: Self.properties[key],
                    required: required
                )
            }

            \(raw: pairs.joined(separator: "\n"))

            return .object(
                .init(required: required, description: description),
                .init(properties: properties)
            )
        }
        """
    }
}

extension Trivia {
    var comments: [String] {
        get {
            var comments = [String]()
            for trivia in self {
                switch trivia {
                case .blockComment(var comment):
                    comment.removeFirst(2)
                    comment.removeFirst(2)
                    comments.append(comment.trimmingCharacters(in: .whitespacesAndNewlines))
                case .docBlockComment(var comment):
                    comment.removeFirst(3)
                    comment.removeFirst(3)
                    comments.append(comment.trimmingCharacters(in: .whitespacesAndNewlines))
                case .lineComment(var comment):
                    comment.removeFirst(2)
                    comments.append(comment.trimmingCharacters(in: .whitespacesAndNewlines))
                case .docLineComment(var comment):
                    comment.removeFirst(3)
                    comments.append(comment.trimmingCharacters(in: .whitespacesAndNewlines))
                default:
                    ()
                }
            }

            return comments
        }
    }
}

extension OpenAPIDocsMacro {
    internal static func typeDeclarationToken(of declaration: some DeclGroupSyntax) throws -> TokenSyntax? {
        if let type = declaration.as(EnumDeclSyntax.self) {
            return type.tokens(viewMode: .all).first { token in
                token.tokenKind == .keyword(.enum)
            }
        } else if let type = declaration.as(StructDeclSyntax.self) {
            return type.tokens(viewMode: .all).first { token in
                token.tokenKind == .keyword(.struct)
            }
        } else {
            throw "Macro not applied to struct or enum"
        }
    }

    internal static func docsExpansion<Declaration, Context>(of node: AttributeSyntax, providingMembersOf declaration: Declaration, in context: Context) throws -> DeclSyntax where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        guard let token = try typeDeclarationToken(of: declaration) else {
            throw "Macro not applied to struct or enum"
        }

        let comments = token.leadingTrivia.comments
        let docs = comments.joined(separator: "\n")

        return """
        public static var description: String { return "\(raw: docs)" }
        """
    }

    public static func codingKeyExpansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> DeclSyntax {
        let cases = declaration.memberBlock.members.compactMap { member -> String? in
            // is a property
            guard
                let variable = member.decl.as(VariableDeclSyntax.self),
                let propertyName = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                return nil
            }

            // Don't support keypaths here
            if let modifiers = variable.modifiers {
                for modifier in modifiers {
                    if case .keyword(.static) = modifier.name.tokenKind {
                        return nil
                    }
                }
            }

            return """
            case \\Self.\(propertyName):
                return CodingKeys.\(propertyName)
            """
        }

        return """
        public static func codingKey<T>(forKeyPath keyPath: KeyPath<Self, T>) -> CodingKey {
            switch keyPath {
            \(raw: cases.joined(separator: "\n"))
            default:
                fatalError("Unknown KeyPath, likely not a stored property")
            }
        }
        """
    }
}

extension OpenAPIRouteMacro: ConformanceMacro {
    public static func expansion<Declaration, Context>(
        of node: AttributeSyntax,
        providingConformancesOf declaration: Declaration,
        in context: Context
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        return [ ("DocumentedRoute", nil) ]
    }
}


extension OpenAPITypeMacro: ConformanceMacro {
    public static func expansion<Declaration, Context>(
        of node: AttributeSyntax,
        providingConformancesOf declaration: Declaration,
        in context: Context
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] where Declaration : DeclGroupSyntax, Context : MacroExpansionContext {
        return [ ("DocumentedContent", nil), ("Codable", nil) ]
    }
}
