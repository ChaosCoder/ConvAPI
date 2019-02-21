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
    case underlying(Error)
    case invalidRequest
    case encodingError
    case invalidHTTPResponse
    case emptyErrorResponse(httpStatusCode: Int)
    case emptyResponse
    case decodingErrorFailure(httpStatusCode: Int, data: Data, error: Error)
    case decodingFailure(Error)
    case applicationError(E)
}

extension RequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .underlying(let error): return error.localizedDescription
        case .invalidRequest: return "Invalid request"
        case .encodingError: return "Encoding error"
        case .invalidHTTPResponse: return "Invalid HTTP response"
        case let .emptyErrorResponse(httpStatusCode): return "Invalid error response with status code \(httpStatusCode)"
        case .emptyResponse: return "Unexpected empty response"
        case .decodingFailure(let error): return "Decoding failed: \(error.localizedDescription)"
        case let .decodingErrorFailure(httpStatusCode, data, error): return "Decoding error response with status code \(httpStatusCode) and data: \(data) failed: \(error.localizedDescription)"
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
            guard error == nil else {
                return completion(.failure(.underlying(error!)))
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return completion(.failure(.invalidHTTPResponse))
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                guard let responseData = data, !responseData.isEmpty else {
                    return completion(.failure(.emptyErrorResponse(httpStatusCode: httpResponse.statusCode)))
                }
                do {
                    let appError = try self.decoder.decode(E.self, from: responseData)
                    return completion(.failure(.applicationError(appError)))
                } catch {
                    return completion(.failure(.decodingErrorFailure(httpStatusCode: httpResponse.statusCode, data: responseData, error: error)))
                }
            }

            guard let responseData = data,
                !responseData.isEmpty else {
                    return completion(.failure(.emptyResponse))
            }

            do {
                let result = try self.decoder.decode(U.self, from: responseData)
                return completion(.success(result))
            } catch {
                return completion(.failure(.decodingFailure(error)))
            }
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
