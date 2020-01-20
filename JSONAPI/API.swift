//
//  API.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import PromiseKit

public protocol API {

    var encoder: JSONEncoder { get set }
    var decoder: JSONDecoder { get set }
    
    func request<T, U, E>(method: APIMethod,
                    baseURL: URL,
                    resource: String,
                    headers: [String: String]?,
                    params: [String: Any]?,
                    body: T?,
                    error: E.Type,
                    decorator: ((inout URLRequest) -> Void)?) -> Promise<U> where T: Encodable, U: Decodable, E: (Error & Decodable)
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
                 error: E.Type,
                 decorator: ((inout URLRequest) -> Void)? = nil) -> Promise<U> where U: Decodable, E: Decodable & Error {

        return request(method: method,
                       baseURL: baseURL,
                       resource: resource,
                       headers: headers,
                       params: params,
                       body: nil as Bool?,
                       error: error,
                       decorator: decorator)
    }
    
    func request<T, E>(method: APIMethod,
                    baseURL: URL,
                    resource: String = "/",
                    headers: [String: String]? = nil,
                    params: [String: Any]? = nil,
                    body: T?,
                    error: E.Type,
                    decorator: ((inout URLRequest) -> Void)? = nil) -> Promise<Void> where T: Encodable, E: Decodable & Error {
        let promise: Promise<EmptyResponse> = request(method: method,
                                                      baseURL: baseURL,
                                                      resource: resource,
                                                      headers: headers,
                                                      params: params,
                                                      body: body,
                                                      error: error,
                                                      decorator: decorator)
        return promise.asVoid().recover({ error in
            if let requestError = error as? RequestError,
                case .emptyResponse = requestError {
                return ()
            } else {
                throw error
            }
        })
    }
    
    func request<E>(method: APIMethod,
                    baseURL: URL,
                    resource: String = "/",
                    headers: [String: String]? = nil,
                    params: [String: Any]? = nil,
                    error: E.Type,
                    decorator: ((inout URLRequest) -> Void)? = nil) -> Promise<Void> where E: Decodable & Error {
        let promise: Promise<EmptyResponse> = request(method: method,
                                                      baseURL: baseURL,
                                                      resource: resource,
                                                      headers: headers,
                                                      params: params,
                                                      body: nil as Bool?,
                                                      error: error,
                                                      decorator: decorator)
        return promise.asVoid().recover({ error in
            if let requestError = error as? RequestError,
                case .emptyResponse = requestError {
                return ()
            } else {
                throw error
            }
        })
    }
}
