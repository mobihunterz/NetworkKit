//
//  Constants.swift
//  NetworkKit
//
//  Created by Paresh Thakor on 17/11/26.
//

enum HTTPHeaderField: String {
    case contentType = "Content-Type"
    case acceptType = "Accept"
    case acceptEncoding = "Accept-Encoding"
    case acceptLanguage = "Accept-Language"
}

enum ContentType: String {
    case json = "application/json"
    case png = "image/png"
    case jpeg = "image/jpeg"
}
