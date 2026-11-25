//
//  NetworkFailure.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//


import Foundation

public enum NetworkFailure: Error {
    case invalidURL(String)
    case responseError(Error)
    case decoding(Error)
    case emptyResponse

    public var underlyingError: Error? {
        switch self {
        case .responseError(let error),
             .decoding(let error):
            return error

        default:
            return nil
        }
    }
}

extension NetworkFailure: LocalizedError {

    public var errorDescription: String? {
        switch self {

        case .invalidURL(let path):
            return "Invalid request URL: \(path)"

        case .responseError(let error):
            return "Network transport failed: \(error.localizedDescription)"

        case .decoding(let error):
            return "Response decoding failed: \(error.localizedDescription)"

        case .emptyResponse:
            return "The server returned an empty response."
        }
    }
}
