//
//  JSONAPI.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

struct JSONAPIError: Error, Codable {
    let type: String
    let description: String
}

extension JSONAPIError: LocalizedError {
    var errorDescription: String? {
        return description
    }
}

public enum RequestError<E>: Error where E: Decodable & Error {
    case invalidRequest
    case encodingError
    case invalidHTTPResponse
    case invalidJSONResponse(httpStatusCode: Int, body: Data?)
    case emptyResponse
    case decodingError
    case applicationError(E)
}

extension RequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Invalid request"
        case .encodingError: return "Encoding error"
        case .invalidHTTPResponse: return "Invalid http response"
        case .invalidJSONResponse(let httpStatusCode, let body): return "Invalid JSON response with status code \(httpStatusCode) and body \(body.debugDescription)"
        case .emptyResponse: return "Empty response"
        case .decodingError: return "Decoding error"
        case .applicationError(let appError): return "Application error: \(appError.localizedDescription)"
        }
    }
}

public struct EmptyResponse: Empty {
    public init() {}
}

public class JSONAPI: API {

    var requester: AsynchronousRequester
    
    public lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    public lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(requester: AsynchronousRequester = URLSession.shared) {
        self.requester = requester
    }
    
    public func request<T, U, E>(method: APIMethod,
                                  baseURL: URL,
                                  resource: String = "/",
                                  headers: [String: String]? = nil,
                                  params: [String: Any]? = nil,
                                  body: T? = nil,
                                  decorator: ((inout URLRequest) -> Void)? = nil,
                                  completion: @escaping ((Result<U, RequestError<E>>) -> Void)) where T: Encodable, U: Decodable, E: Decodable & Error {
        let data: Data?
        if let body = body {
            guard let encodedBody = try? encoder.encode(body) else {
                return completion(.failure(.encodingError))
            }
            data = encodedBody
        } else {
            data = nil
        }
        
        guard var request = try? self.request(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: data) else {
            return completion(.failure(.invalidRequest))
        }
        decorator?(&request)
        
        let dataTask = requester.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else {
                return completion(.failure(.invalidHTTPResponse))
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                guard let responseData = data,
                    let appError = try? self.decoder.decode(E.self, from: responseData) else {
                    return completion(.failure(.invalidJSONResponse(httpStatusCode: httpResponse.statusCode, body: data)))
                }
                return completion(.failure(.applicationError(appError)))
            }
            
            guard let responseData = data,
                !responseData.isEmpty else {
                    return completion(.failure(.emptyResponse))
            }
            
            guard let result = try? self.decoder.decode(U.self, from: responseData) else {
                return completion(.failure(.decodingError))
            }
            
            completion(.success(result))
        }
        dataTask.resume()
    }

    private func request(method: APIMethod = .GET,
                        baseURL: URL,
                        resource: String = "/",
                        headers: [String: String]? = nil,
                        params: [String: Any]? = nil,
                        body: Data? = nil) throws -> URLRequest {
        
        guard let resourceURL = URL(string: baseURL.absoluteString + resource),
            var urlComponents = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
            throw RequestError<JSONAPIError>.invalidRequest
        }

        if let params = params {
            urlComponents.queryItems = params.compactMap ({ arg -> URLQueryItem in
                let (key, value) = arg
                let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                return URLQueryItem(name: key, value: encodedValue)
            })
        }

        guard let url = urlComponents.url else {
            throw RequestError<JSONAPIError>.invalidRequest
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

        return request
    }
}
