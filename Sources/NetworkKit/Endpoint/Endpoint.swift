//
//  Endpoint.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//
import Alamofire
import Foundation

/// A description of a single HTTP request that `NetworkClient` can execute.
///
/// Conform with an enum of API routes (see the SimpleAPICall example). Provide at least
/// `path`, `method`, and `baseUrl`. Query items, body, and extra headers default to empty.
///
/// `RequestBuilder` builds the URL as `baseUrl` + `path`, appends `queryParameters`,
/// then JSON-encodes `parameters` into the HTTP body when present.
public protocol Endpoint: Sendable {
    /// Path relative to `baseUrl`.
    ///
    /// A leading slash is optional; it is normalized when the URL is built.
    /// Must be non-empty and must not include a scheme or host (`://` or `//`).
    var path: String { get }
    
    /// HTTP method for the request (`GET`, `POST`, and so on).
    var method: HTTPMethod { get }
    
    /// Query items appended to the URL.
    ///
    /// Keys and string values become `URLQueryItem`s. Existing query items on `baseUrl`
    /// are preserved. Non-string values are currently dropped.
    /// Defaults to `nil`.
    var queryParameters: Parameters? { get }
    
    /// HTTP body payload.
    ///
    /// Encoding in `RequestBuilder`:
    /// - `String`: UTF-8 body (not JSON-quoted)
    /// - other `Encodable`: `JSONEncoder`
    /// - dictionary / array: `JSONSerialization`
    ///
    /// Defaults to `nil` (no body). Prefer query items for `GET`.
    var parameters: Any? { get }
    
    /// Extra request headers, merged over JSON `Accept` and `Content-Type`.
    ///
    /// Endpoint values win on key conflicts. `nil` and `[:]` both mean “no extras”.
    /// Defaults to `[:]`.
    var headers: [String: String]? { get }
    
    /// Origin for this request (API, assets, documents, and similar hosts).
    ///
    /// Path and query on this URL are kept; `path` is appended and
    /// `queryParameters` are added.
     var baseUrl: URL { get }
    
    /// Whether this request requires authentication.
    //var requiresAuthentication: Bool { get }

}

// Default implementations keep simple endpoints concise.
public extension Endpoint {

    var queryParameters: Parameters? {
        nil
    }
    
    var parameters: Any? {
        nil
    }

    var headers: [String: String] {
        [:]
    }

//    var requiresAuthentication: Bool {
//        true
//    }
}
