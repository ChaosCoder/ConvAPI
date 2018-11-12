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

public class JSONAPI: API {

    var requester: AsynchronousRequester

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
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            guard let httpResponse = response as? HTTPURLResponse else {
                return completion(.failure(.invalidHTTPResponse))
            }

            guard let responseData = data else {
                return completion(.failure(.unexpectedEmptyResponse))
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                guard let error = try? decoder.decode(E.self, from: responseData) else {
                    return completion(.failure(.invalidJSONResponse(httpStatusCode: httpResponse.statusCode, body: data)))
                }
                return completion(.failure(.applicationError(error)))
            }

            guard let response = try? decoder.decode(U.self, from: responseData) else {
                return completion(.failure(.decodingError))
            }

            completion(.success(response))
        }
        dataTask.resume()
    }

    private func request(method: APIMethod = .GET,
                        baseURL: URL,
                        resource: String = "/",
                        headers: [String: String]? = nil,
                        params: [String: Any]? = nil,
                        body: Data? = nil) throws -> URLRequest {

        let resourceURL = baseURL.appendingPathComponent(resource)

        guard var urlComponents = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
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
