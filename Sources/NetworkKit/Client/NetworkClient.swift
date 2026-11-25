//
//  NetworkClient.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//

import Alamofire
import Foundation

/// Alamofire-backed client that performs HTTP requests described by `Endpoint`.
///
/// Use ``shared`` for a default `Session`, or inject a custom `Session` (tests, interceptors,
/// `URLProtocol` stubs).
///
/// `execute(_:)` returns the raw body and status. `execute(_:as:decoder:)` runs that path
/// then JSON-decodes the body.
///
/// - Throws: `AFError` for invalid URLs, transport failure, non-2xx status (`.validate()`),
///   or decode failure. `NetworkFailure` is not used here.
public final class NetworkClient: NetworkTransport {
    
    /// Shared client using Alamofire’s default `Session`.
    public static let shared = NetworkClient()
    
    /// Session that sends requests. Inject a stubbed session in tests.
    private let session: Session

    /// Creates a client.
    ///
    /// - Parameter session: Alamofire session. Defaults to `Session()`.
    public init(session: Session = .init()) {
        self.session = session
    }

    /// Sends `endpoint` and returns the raw HTTP result.
    ///
    /// Builds the request with `RequestBuilder`, then `.validate()` (2xx only). Empty bodies
    /// on 2xx are allowed (`emptyResponseCodes: 200..<300`). Missing `HTTPURLResponse`
    /// becomes `AFError.sessionTaskFailed` with `URLError.badServerResponse`.
    ///
    /// - Parameter endpoint: Route to execute.
    /// - Returns: Body bytes, status code, and stringified response headers.
    /// - Throws: `AFError` from URL building, the session, validation, or serialization.
    public func execute(_ endpoint: Endpoint) async throws -> NetworkResponse {
        let route = RequestBuilder(endpoint: endpoint)
        let response = await session
            .request(route)
            .validate()
            .serializingData(emptyResponseCodes: Set(200..<300))
            .response

        if let error = response.error {
            throw error
        }

        guard let httpResponse = response.response else {
            throw AFError.sessionTaskFailed(error: URLError(.badServerResponse))
        }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
            guard let key = item.key as? String else {
                return
            }

            result[key] = String(describing: item.value)
        }

        return NetworkResponse(
            data: response.data ?? Data(),
            statusCode: httpResponse.statusCode,
            headers: headers
        )
    }
    
    /// Sends `endpoint` and JSON-decodes the body as `T`.
    ///
    /// Calls ``execute(_:)`` first, so HTTP and transport errors happen before decoding.
    /// Decode errors are wrapped as `AFError.responseSerializationFailed(.decodingFailed)`.
    ///
    /// - Parameters:
    ///   - endpoint: Route to execute.
    ///   - type: Decodable type (pass `User.self` or `[User].self`).
    ///   - decoder: JSON decoder. Defaults to `JSONDecoder()`.
    /// - Returns: Decoded value.
    /// - Throws: The same errors as ``execute(_:)``, plus wrapped decode failures.
    public func execute<T: Decodable>(_ endpoint: Endpoint, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let response = try await execute(endpoint)

        do {
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
        }
    }
}
