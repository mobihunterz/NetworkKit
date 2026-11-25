//
//  NetworkTransport.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//
import Foundation

public protocol NetworkTransport: Sendable {
    func execute(_ endpoint: Endpoint) async throws -> NetworkResponse
    func execute<T: Decodable>(_ endpoint: Endpoint, as type: T.Type, decoder: JSONDecoder) async throws -> T
}
