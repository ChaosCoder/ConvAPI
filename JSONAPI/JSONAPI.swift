//
//  JSONAPI.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import PromiseKit

struct JSONAPIError: Error, Codable {
    let type: String
    let description: String
}

extension JSONAPIError: LocalizedError {
    var errorDescription: String? {
        return description
    }
}

public enum RequestError {
    case invalidRequest
    case invalidHTTPResponse
    case emptyErrorResponse(httpStatusCode: Int)
    case emptyResponse
}

extension RequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Invalid request"
        case .invalidHTTPResponse: return "Invalid HTTP response"
        case let .emptyErrorResponse(httpStatusCode): return "Invalid error response with status code \(httpStatusCode)"
        case .emptyResponse: return "Unexpected empty response"
        }
    }
}

public class JSONAPI: API {
    
    var requester: AsynchronousRequester
    
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder
    
    public convenience init(requester: AsynchronousRequester = URLSession.shared) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        self.init(requester: requester, encoder: encoder, decoder: decoder)
    }
    
    public init(requester: AsynchronousRequester = URLSession.shared, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.requester = requester
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public func request<T, U, E>(method: APIMethod,
                                 baseURL: URL,
                                 resource: String = "/",
                                 headers: [String: String]? = nil,
                                 params: [String: Any]? = nil,
                                 body: T? = nil,
                                 error: E.Type,
                                 decorator: ((inout URLRequest) -> Void)? = nil) -> Promise<U> where T: Encodable, U: Decodable, E: (Error & Decodable) {
        return firstly { () -> Promise<(data: Data, response: URLResponse)> in
            let data = try body.map { try encoder.encode($0) }
            let task = try request(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: data, decorator: decorator)
            
            return requester.dataTask(.promise, with: task)
        }.map { data, response -> U in
            return try self.parseResponse(data: data, response: response, error: error)
        }
    }
    
    private func request(method: APIMethod = .GET,
                         baseURL: URL,
                         resource: String = "/",
                         headers: [String: String]? = nil,
                         params: [String: Any]? = nil,
                         body: Data? = nil,
                         decorator: ((inout URLRequest) -> Void)? = nil) throws -> URLRequest {
        
        guard let resourceURL = URL(string: baseURL.absoluteString + resource),
            var urlComponents = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
                throw RequestError.invalidRequest
        }
        
        if let params = params {
            urlComponents.queryItems = params.compactMap ({ arg -> URLQueryItem in
                let (key, value) = arg
                let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                return URLQueryItem(name: key, value: encodedValue)
            })
        }
        
        guard let url = urlComponents.url else {
            throw RequestError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        decorator?(&request)
        
        return request
    }
    
    private func parseResponse<U, E>(data: Data, response: URLResponse, error: E.Type) throws -> U where U: Decodable, E: (Error & Decodable) {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RequestError.invalidHTTPResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            guard !data.isEmpty else {
                throw RequestError.emptyErrorResponse(httpStatusCode: httpResponse.statusCode)
            }
            let appError = try self.decoder.decode(E.self, from: data)
            throw appError
        }
        
        guard !data.isEmpty else {
            throw RequestError.emptyResponse
        }
        
        return try self.decoder.decode(U.self, from: data)
    }
}
