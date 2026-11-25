//
//  RequestBuilder.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//

import Alamofire
import Foundation

struct RequestBuilder: URLRequestConvertible {
    //private let configuration: NetworkConfiguration
    private let endpoint: Endpoint

    init(endpoint: Endpoint) {
        //self.configuration = configuration
        self.endpoint = endpoint
    }

    public func asURLRequest() throws -> URLRequest {
        guard !endpoint.path.isEmpty else {
            throw AFError.invalidURL(url: endpoint.path)
        }
        
        // Prevent accidental host inclusion into an endpoint path.
        guard !endpoint.path.contains("://"),
              !endpoint.path.hasPrefix("//") else {
            throw AFError.invalidURL(url: endpoint.path)
        }
        
        // Covert base URL into components
        guard var components = URLComponents(
            url: endpoint.baseUrl,
            resolvingAgainstBaseURL: false) else {
            throw AFError.invalidURL(url: endpoint.baseUrl.absoluteString)
        }
        
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        let endpointPath = endpoint.path.hasPrefix("/") ? endpoint.path : "/" + endpoint.path
        components.path = basePath + endpointPath
        
        let newQueryParams = endpoint.queryParameters?.compactMap { key, value -> URLQueryItem? in
            guard let stringValue = value as? String else {
                return nil
            }
            return URLQueryItem(name: key, value: stringValue)
        } ?? []
        if !newQueryParams.isEmpty {
            // Preserve existing query parameters
            components.queryItems = (components.queryItems ?? [] ) + newQueryParams
        }

        guard let url = components.url else {
            throw AFError.invalidURL(url: endpoint.path)
        }

        var urlRequest = URLRequest(url: url)

        // HTTP Method
        urlRequest.httpMethod = endpoint.method.rawValue

        // Headers
        var headers: [String: String] = [
            HTTPHeaderField.acceptType.rawValue: ContentType.json.rawValue,
            HTTPHeaderField.contentType.rawValue: ContentType.json.rawValue
        ]
        headers.merge(endpoint.headers ?? [:]) { _, new in new }
        
        urlRequest.headers = HTTPHeaders(headers)

        if let params = endpoint.parameters {
            do {
                if let parameters = params as? Encodable {
                    // Encodable Parameters
                    if let isStringValue = params as? String {
                        urlRequest.httpBody = Data(isStringValue.utf8)
                    } else {
                        urlRequest.httpBody = try JSONEncoder().encode(parameters)
                    }
                } else {
                    // Serialise Dictionary and other objects directly to JSON if not encodable
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params)
                }
            } catch {
                throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
            }
        }

        return urlRequest
    }
}
