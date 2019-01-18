//
//  API.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

public protocol API {

    var encoder: JSONEncoder { get set }
    var decoder: JSONDecoder { get set }
    
    func request<T, U, E>(method: APIMethod,
                    baseURL: URL,
                    resource: String,
                    headers: [String: String]?,
                    params: [String: Any]?,
                    body: T?,
                    decorator: ((inout URLRequest) -> Void)?,
                    completion: @escaping ((Result<U, RequestError<E>>) -> Void)) where T: Encodable, U: Decodable, E: Decodable & Error
    
    func request<T, E>(method: APIMethod,
                       baseURL: URL,
                       resource: String,
                       headers: [String: String]?,
                       params: [String: Any]?,
                       body: T?,
                       decorator: ((inout URLRequest) -> Void)?,
                       completion: @escaping (RequestError<E>?) -> Void) where T: Encodable, E: Decodable & Error
}

public protocol Empty: Codable {
    init()
}

public extension API {

    func request<U, E>(method: APIMethod,
                 baseURL: URL,
                 resource: String = "/",
                 headers: [String: String]? = nil,
                 params: [String: Any]? = nil,
                 decorator: ((inout URLRequest) -> Void)? = nil,
                 completion: @escaping ((Result<U, RequestError<E>>) -> Void)) where U: Decodable, E: Decodable & Error {

        request(method: method,
                baseURL: baseURL,
                resource: resource,
                headers: headers,
                params: params,
                body: nil as Bool?,
                decorator: decorator,
                completion: completion)
    }
    
    func request<E>(method: APIMethod,
                       baseURL: URL,
                       resource: String = "/",
                       headers: [String: String]? = nil,
                       params: [String: Any]? = nil,
                       decorator: ((inout URLRequest) -> Void)? = nil,
                       completion: @escaping (RequestError<E>?) -> Void) where E: Decodable & Error {
        request(method: method,
                baseURL: baseURL,
                resource: resource,
                headers: headers,
                params: params,
                body: nil as Bool?,
                decorator: decorator,
                completion: completion)
    }
    
    func request<T, E>(method: APIMethod,
                              baseURL: URL,
                              resource: String = "/",
                              headers: [String: String]? = nil,
                              params: [String: Any]? = nil,
                              body: T? = nil,
                              decorator: ((inout URLRequest) -> Void)? = nil,
                              completion: @escaping (RequestError<E>?) -> Void) where T: Encodable, E: Decodable & Error {
        request(method: method,
                baseURL: baseURL,
                resource: resource,
                headers: headers,
                params: params,
                body: body,
                decorator: decorator,
                completion: { (result: Result<EmptyResponse, RequestError<E>>) in
            switch result {
            case .success(_):
                completion(nil)
            case .failure(let error):
                if case .emptyResponse = error {
                    completion(nil)
                } else {
                    completion(error)
                }
            }
        })
    }
}
