import Alamofire
import Foundation
import NetworkKit

struct StubEndpoint: Endpoint, @unchecked Sendable {
    var path: String
    var method: HTTPMethod
    var queryParameters: Parameters?
    var parameters: Any?
    var headers: [String: String]?
    var baseUrl: URL

    init(
        path: String = "/resource",
        method: HTTPMethod = .get,
        queryParameters: Parameters? = nil,
        parameters: Any? = nil,
        headers: [String: String]? = nil,
        baseUrl: URL = URL(string: "https://api.test")!
    ) {
        self.path = path
        self.method = method
        self.queryParameters = queryParameters
        self.parameters = parameters
        self.headers = headers
        self.baseUrl = baseUrl
    }
}

struct UserDTO: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct CreateUserBody: Codable, Equatable {
    let name: String
}

enum TestJSON {
    static let user = UserDTO(id: 1, name: "Ada")

    static var userData: Data {
        try! JSONEncoder().encode(user)
    }

    static var userArrayData: Data {
        try! JSONEncoder().encode([user])
    }

    static var invalid: Data {
        Data("{\"id\":".utf8)
    }
}

enum MockNetwork {
    static func makeClient() -> NetworkClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return NetworkClient(session: Session(configuration: configuration))
    }
}
