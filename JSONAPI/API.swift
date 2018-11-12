//
//  API.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

public enum RequestError<E>: Error where E: Decodable & Error {
    case invalidRequest
    case encodingError
    case invalidHTTPResponse
    case invalidJSONResponse(httpStatusCode: Int, body: Data?)
    case unexpectedEmptyResponse
    case decodingError
    case applicationError(E)
}

public protocol API {

    func request<T, U, E>(method: APIMethod,
                    baseURL: URL,
                    resource: String,
                    headers: [String: String]?,
                    params: [String: Any]?,
                    body: T?,
                    decorator: ((inout URLRequest) -> Void)?,
                    completion: @escaping ((Result<U, RequestError<E>>) -> Void)) where T: Encodable, U: Decodable, E: Decodable & Error
}

protocol Empty: Codable {
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
}
