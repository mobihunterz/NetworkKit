import Alamofire
import Foundation
import Testing
@testable import NetworkKit

/// Serialized because `MockURLProtocol` stores a process-wide stub.
@Suite(.serialized)
struct NetworkClientTests {

    private let client = MockNetwork.makeClient()

    init() {
        MockURLProtocol.reset()
    }

    // MARK: - Success: HTTP methods

    @Test("GET 200 returns body, status, and response headers")
    func getSuccess() async throws {
        MockURLProtocol.stub = .success(
            headers: ["Content-Type": "application/json", "X-Request-Id": "abc"],
            data: TestJSON.userData
        )

        let response = try await client.execute(StubEndpoint(path: "/users/1", method: .get))

        #expect(response.statusCode == 200)
        #expect(try JSONDecoder().decode(UserDTO.self, from: response.data) == TestJSON.user)
        #expect(response.headers["X-Request-Id"] == "abc")
        #expect(MockURLProtocol.lastRequest?.httpMethod == "GET")
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://api.test/users/1")
    }

    @Test("POST, PUT, PATCH, and DELETE succeed for 2xx")
    func mutatingMethodsSucceed() async throws {
        let methods: [HTTPMethod] = [.post, .put, .patch, .delete]

        for method in methods {
            MockURLProtocol.reset()
            MockURLProtocol.stub = .success(statusCode: 201, data: TestJSON.userData)

            let response = try await client.execute(
                StubEndpoint(path: "/users", method: method, parameters: ["name": "Ada"])
            )

            #expect(response.statusCode == 201)
            #expect(MockURLProtocol.lastRequest?.httpMethod == method.rawValue)
        }
    }

    // MARK: - Success: URL construction

    @Test("Leading slash on path is optional")
    func pathSlashNormalized() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(StubEndpoint(path: "users"))
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://api.test/users")

        _ = try await client.execute(
            StubEndpoint(path: "/users", baseUrl: URL(string: "https://api.test/v1/")!)
        )
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://api.test/v1/users")
    }

    @Test("Query parameters are appended and existing base-URL query is kept")
    func queryParametersMerged() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(
            StubEndpoint(
                path: "/search",
                queryParameters: ["q": "swift", "limit": "10"],
                baseUrl: URL(string: "https://api.test/v1?source=app")!
            )
        )

        let url = try #require(MockURLProtocol.lastRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })

        #expect(url.path == "/v1/search")
        #expect(values["source"] == "app")
        #expect(values["q"] == "swift")
        #expect(values["limit"] == "10")
    }

    @Test("Non-string query values are dropped")
    func nonStringQueryValuesDropped() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(
            StubEndpoint(path: "/search", queryParameters: ["q": "swift", "page": 2])
        )

        let url = try #require(MockURLProtocol.lastRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains { $0.name == "q" && $0.value == "swift" })
        #expect(!items.contains { $0.name == "page" })
    }

    // MARK: - Success: headers

    @Test("Default JSON Accept and Content-Type are set")
    func defaultHeaders() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(StubEndpoint(headers: nil))

        let headers = MockURLProtocol.lastRequest?.allHTTPHeaderFields ?? [:]
        #expect(headers["Accept"] == "application/json")
        #expect(headers["Content-Type"] == "application/json")
    }

    @Test("Custom headers merge and override defaults")
    func customHeadersOverride() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(
            StubEndpoint(headers: [
                "Authorization": "Bearer token",
                "Content-Type": "text/plain",
            ])
        )

        let headers = MockURLProtocol.lastRequest?.allHTTPHeaderFields ?? [:]
        #expect(headers["Authorization"] == "Bearer token")
        #expect(headers["Content-Type"] == "text/plain")
        #expect(headers["Accept"] == "application/json")
    }

    // MARK: - Success: request body encodings

    @Test("Dictionary parameters are JSON-serialized")
    func dictionaryBody() async throws {
        MockURLProtocol.stub = .success(statusCode: 201)

        _ = try await client.execute(
            StubEndpoint(method: .post, parameters: ["name": "Ada"])
        )

        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["name"] == "Ada")
    }

    @Test("Encodable parameters are JSON-encoded")
    func encodableBody() async throws {
        MockURLProtocol.stub = .success(statusCode: 201)

        _ = try await client.execute(
            StubEndpoint(method: .post, parameters: CreateUserBody(name: "Ada"))
        )

        let body = try #require(MockURLProtocol.lastBody)
        let decoded = try JSONDecoder().decode(CreateUserBody.self, from: body)
        #expect(decoded == CreateUserBody(name: "Ada"))
    }

    @Test("String parameters are written as UTF-8, not JSON-quoted")
    func stringBody() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(
            StubEndpoint(method: .post, parameters: "raw-payload")
        )

        let body = try #require(MockURLProtocol.lastBody)
        #expect(String(data: body, encoding: .utf8) == "raw-payload")
    }

    @Test("GET with no parameters sends an empty body")
    func getHasNoBody() async throws {
        MockURLProtocol.stub = .success()

        _ = try await client.execute(StubEndpoint(method: .get, parameters: nil))

        let body = MockURLProtocol.lastBody
        #expect(body == nil || body?.isEmpty == true)
    }

    // MARK: - Success: decoding

    @Test("Decodable execute returns a typed model")
    func decodeSuccess() async throws {
        MockURLProtocol.stub = .success(data: TestJSON.userData)

        let user = try await client.execute(StubEndpoint(path: "/users/1"), as: UserDTO.self)
        #expect(user == TestJSON.user)
    }

    @Test("Decodable execute returns an array")
    func decodeArraySuccess() async throws {
        MockURLProtocol.stub = .success(data: TestJSON.userArrayData)

        let users = try await client.execute(StubEndpoint(path: "/users"), as: [UserDTO].self)
        #expect(users == [TestJSON.user])
    }

    @Test("Custom JSONDecoder is used")
    func customDecoder() async throws {
        struct SnakeUser: Decodable, Equatable {
            let displayName: String
        }

        MockURLProtocol.stub = .success(data: Data("{\"display_name\":\"Ada\"}".utf8))

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let user = try await client.execute(StubEndpoint(path: "/users/1"), as: SnakeUser.self, decoder: decoder)
        #expect(user == SnakeUser(displayName: "Ada"))
    }

    @Test("2xx responses with an empty body succeed for raw execute")
    func emptyBodySuccess() async throws {
        MockURLProtocol.stub = .success(statusCode: 200, data: Data())
        let ok = try await client.execute(StubEndpoint(path: "/health"))
        #expect(ok.statusCode == 200)
        #expect(ok.data.isEmpty)

        MockURLProtocol.stub = .success(statusCode: 204, data: Data())
        let noContent = try await client.execute(StubEndpoint(path: "/users/1", method: .delete))
        #expect(noContent.statusCode == 204)
        #expect(noContent.data.isEmpty)
    }

    // MARK: - Failure: HTTP status (Alamofire validate)

    @Test("Client and server errors fail validation", arguments: [400, 401, 403, 404, 409, 422, 500, 502, 503])
    func httpErrorStatus(_ statusCode: Int) async {
        MockURLProtocol.stub = .success(statusCode: statusCode, data: Data("{\"error\":\"fail\"}".utf8))

        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: "/users/1"))
        }
    }

    // MARK: - Failure: transport

    @Test("Transport errors are surfaced")
    func transportError() async {
        MockURLProtocol.stub = .failure(URLError(.notConnectedToInternet))

        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint())
        }
    }

    @Test("Timed-out requests fail")
    func timeoutError() async {
        MockURLProtocol.stub = .failure(URLError(.timedOut))

        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint())
        }
    }

    // MARK: - Failure: decoding

    @Test("Invalid JSON fails typed execute")
    func decodeInvalidJSON() async {
        MockURLProtocol.stub = .success(data: TestJSON.invalid)

        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: "/users/1"), as: UserDTO.self)
        }
    }

    @Test("Empty 200 body fails typed execute")
    func decodeEmptyBody() async {
        MockURLProtocol.stub = .success(data: Data())

        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: "/users/1"), as: UserDTO.self)
        }
    }

    @Test("HTTP error fails before decoding")
    func httpErrorSkipsDecoding() async {
        MockURLProtocol.stub = .success(statusCode: 500, data: TestJSON.userData)

        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: "/users/1"), as: UserDTO.self)
        }
    }

    // MARK: - Failure: request building (exercised through execute)

    @Test("Empty path fails before the request is sent")
    func emptyPath() async {
        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: ""))
        }
        #expect(MockURLProtocol.lastRequest == nil)
    }

    @Test("Path that includes a host fails")
    func pathWithScheme() async {
        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: "https://evil.test/users"))
        }
        #expect(MockURLProtocol.lastRequest == nil)
    }

    @Test("Protocol-relative path fails")
    func pathWithDoubleSlash() async {
        await #expect(throws: AFError.self) {
            try await client.execute(StubEndpoint(path: "//cdn.test/asset"))
        }
        #expect(MockURLProtocol.lastRequest == nil)
    }

    @Test("Non-finite numeric body values fail parameter encoding")
    func invalidParameterEncoding() async {
        await #expect(throws: AFError.self) {
            try await client.execute(
                StubEndpoint(method: .post, parameters: Double.nan)
            )
        }
        #expect(MockURLProtocol.lastRequest == nil)
    }
}
