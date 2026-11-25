//
//  NetworkRequest.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//

import Alamofire
import Foundation

public struct NetworkRequest: Sendable {

    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
    public let timeoutInterval: TimeInterval

    public init(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: Data?,
        timeoutInterval: TimeInterval
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
}
