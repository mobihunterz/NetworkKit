//
//  NetworkManager.swift
//  SimpleAPICall
//
//  Created by Paresh Thakor on 17/11/26.
//

import NetworkKit

final class NetworkManager {
    static let shared = NetworkManager()
    
    var postClient: NetworkClient

    init(client: NetworkClient = NetworkClient()) {
        self.postClient = client
    }
}
