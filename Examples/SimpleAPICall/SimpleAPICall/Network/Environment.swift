//
//  Environment.swift
//  SimpleAPICall
//
//  Created by Paresh Thakor on 17/11/26.
//
import Foundation
import NetworkKit

enum Environment {
    case stage
    case debug
    
    var postNetworkConfiguration: URL {
        switch self {
        case .stage:
            URL(string: "https://jsonplaceholder.typicode.com")!
        case .debug:
            URL(string: "https://jsonplaceholder.typicode.com")!
        }
    }
    
    var iTunesNetworkConfiguration: URL {
        URL(string: "https://itunes.apple.com/")!
    }
}
