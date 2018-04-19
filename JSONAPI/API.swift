//
//  API.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

public enum APIError: Error {
    case notReachable
    case invalidRequest
    case invalidResponse
    case underlying(Error)
}

public enum HTTPMethod: String {
    case GET
    case POST
    case DELETE
    case PUT
    case HEAD
    case OPTIONS
    case TRACE
}

public protocol API {
    
    func trigger<U>(method: HTTPMethod,
                    baseURL: URL,
                    resource: String,
                    headers: [String : String]?,
                    params: [String: Any]?,
                    body: U?,
                    completion: @escaping ((APIError?) -> Void)) where U: Encodable
    
    func retrieve<T, U>(method: HTTPMethod,
                        baseURL: URL,
                        resource: String,
                        headers: [String : String]?,
                        params: [String: Any]?,
                        body: U?,
                        completion: @escaping ((Result<T, APIError>) -> Void)) where T: Decodable, U: Encodable
}

public extension API {
    
    func trigger(method: HTTPMethod,
                 baseURL: URL,
                 resource: String = "/",
                 headers: [String : String]? = nil,
                 params: [String: Any]? = nil,
                 completion: @escaping ((APIError?) -> Void)) {
        trigger(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: nil as Empty?, completion: completion)
    }
    
    func retrieve<T>(method: HTTPMethod,
                     baseURL: URL,
                     resource: String = "/",
                     headers: [String : String]? = nil,
                     params: [String: Any]? = nil,
                     completion: @escaping ((Result<T, APIError>) -> Void)) where T: Decodable {
        retrieve(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: nil as Empty?, completion: completion)
    }
}

private struct Empty: Encodable {}
