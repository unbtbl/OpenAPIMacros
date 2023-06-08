// The Swift Programming Language
// https://docs.swift.org/swift-book
import OpenAPIKit30
import Foundation

@attached(member, names: named(codingKey))
@attached(conformance)
public macro Model() = #externalMacro(module: "OpenAPIMacros", type: "ModelMacro")

@attached(member, names: named(description), named(codingKey), named(operation))
@attached(conformance)
public macro OpenAPIRoute() = #externalMacro(module: "OpenAPIMacros", type: "OpenAPIRouteMacro")

@attached(member, names: named(description), named(properties), named(codingKey), named(content), named(schema), named(examples))
@attached(conformance)
public macro OpenAPIType() = #externalMacro(module: "OpenAPIMacros", type: "OpenAPITypeMacro")

/// Check if provided string literal is a valid URL and produce a non-optional
/// URL value. Emit error otherwise.
@freestanding(expression) public macro URL(_ stringLiteral: String) -> URL = #externalMacro(module: "OpenAPIMacros", type: "URLMacro")

@attached(member)
public macro OpenAPIExample(name: String) = #externalMacro(module: "OpenAPIMacros", type: "OpenAPIExampleMacro")

public protocol ModelProtocol: Identifiable, Codable where ID: Codable {
    static func codingKey<T>(forKeyPath: KeyPath<Self, T>) -> CodingKey
}

public protocol Route {
    associatedtype Request
    associatedtype Response

    static func execute(_ request: Request) async throws -> Response
}

public protocol Documented {
    static var description: String { get }
}

public protocol OpenAPISchema {
    static func schema(description: String?, required: Bool) -> JSONSchema
}

public protocol DocumentedContent: Codable, Documented, OpenAPISchema {
    static var examples: [String: Self] { get }
    static var contentTypes: Set<OpenAPI.ContentType> { get }
}

public protocol DocumentedRoute: Route, Documented where Request: DocumentedContent, Response: DocumentedContent {
    static var method: OpenAPI.HttpMethod { get }
    static var request: OpenAPI.Request { get }
    static var response: OpenAPI.Response { get }
    static var operation: OpenAPI.Operation { get }
}

extension DocumentedContent {
    public static var content: OpenAPI.Content {
        var examples = OpenAPI.Example.Map()

        for (name, example) in Self.examples {
            let json = try! JSONEncoder().encode(example)
            let object = try! JSONSerialization.jsonObject(with: json)
            examples[name] = .b(.init(value: .b(.init(object))))
        }

        return .init(schema: schema(description: nil, required: true), examples: examples)
    }

    public static var contentTypes: Set<OpenAPI.ContentType> {
        return [.json]
    }
}

extension DocumentedRoute {
    public static var request: OpenAPI.Request {
        var contentMap = OpenAPI.Content.Map()
        for contentType in Request.contentTypes {
            contentMap[contentType] = Request.content
        }

        return .init(
            description: Request.description,
            content: contentMap,
            required: true
        )
    }

    public static var response: OpenAPI.Response {
        var contentMap = OpenAPI.Content.Map()
        for contentType in Response.contentTypes {
            contentMap[contentType] = Response.content
        }

        return .init(
            description: Response.description,
            content: contentMap
        )
    }

    public static var operation: OpenAPI.Operation {
        .init(
            requestBody: .b(request),
            responses: [
                .default: .b(response)
            ]
        )
    }
}

extension String: OpenAPISchema {
    public static func schema(description: String?, required: Bool) -> JSONSchema {
        .string(.init(required: required, description: description), .init())
    }
}
