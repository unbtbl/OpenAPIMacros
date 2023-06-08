import OpenAPI
import OpenAPIKit30
import Foundation
import SwiftUI

@Model
struct User {
    let id: String
    var username: String
}

@OpenAPIType
struct UserDTO {
    let id: String
    var username: String
}

@OpenAPIRoute
/// Processes a login request, and returns upon successful authentication
enum VaporLoginHandler {
    static var method: OpenAPI.HttpMethod { .post }

    @OpenAPIType
    struct Request {
        enum CodingKeys: String, CodingKey {
            case username = "email"
            case password
        }

        /// The email address belonging to your account, used to log in
        let username: String

        /// The secret password, not to be shared!
        var password: String

        @OpenAPIExample(name: "login")
        static let login = Request(username: "joannis@orlandos.nl", password: "kaas")
    }

    @OpenAPIType
    /// Returns the user's profile and token
    struct Response {
        /// The now authenticated user - you!
        let user: UserDTO

        /// The `Authorization: Bearer` token to be provided from now on as an HTTP header
        let token: String
    }

    static func execute(_ request: Request) async throws -> Response {
        Response(
            user: .init(id: UUID().uuidString, username: request.username),
            token: UUID().uuidString
        )
    }
}

print(VaporLoginHandler.Request.codingKey(forKeyPath: \.username))
print(VaporLoginHandler.description)
let spec = OpenAPI.Document(
    info: .init(title: "My API", version: "1.0"),
    servers: [
        .init(
            url: #URL("https://api.example.com")
        )
    ],
    paths: [
        "/auth/login": .init(post: VaporLoginHandler.operation)
    ],
    components: .init()
)

try print(String(data: JSONEncoder().encode(spec), encoding: .utf8)!)
