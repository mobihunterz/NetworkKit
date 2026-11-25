//
//  APIEndpoint.swift
//  SimpleAPICall
//
//  Created by Paresh Thakor on 17/11/26.
//

import NetworkKit
import Alamofire
import Foundation

enum APIEndpoint: Endpoint {
    case posts
    
    var path: String {
        "/posts"
    }
    
    var method: HTTPMethod {
        .get
    }
    
    var headers: [String : String]? {
        nil
    }
    
    var baseUrl: URL {
        Environment.stage.postNetworkConfiguration
    }
}

enum iTunesAPIEndpoint: Endpoint {
    case search
    
    var path: String {
        "/search"
    }
    
    var method: HTTPMethod {
        .get
    }
    
    var headers: [String : String]? {
        nil
    }
    
    var baseUrl: URL {
        Environment.stage.iTunesNetworkConfiguration
    }
}
