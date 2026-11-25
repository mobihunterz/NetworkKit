//
//  ResponseDTO.swift
//  SimpleAPICall
//
//  Created by Paresh Thakor on 17/11/26.
//
//
struct ResponseDTO: Decodable, Sendable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}
