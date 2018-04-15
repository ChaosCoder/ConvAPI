//
//  JSONAPI
//
//  Created by Andreas Ganske on 16.03.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

enum BackendError: Error {
    case notReachable
    case invalidRequest
    case invalidResponse
    case underlying(Error)
}

enum HTTPMethod: String {
    case GET
    case POST
}

protocol JSONHTTPRequestable {
    func request<T: Decodable>(method: HTTPMethod, baseURL: URL, resource: String, headers: [String: String]?, params: [String: Any]?, completion: ((Result<T, BackendError>) -> Void)?) -> URLSessionTask?
    func request<T: Decodable, U: Encodable>(method: HTTPMethod, baseURL: URL, resource: String, headers: [String: String]?, params: [String: Any]?, body: U, completion: ((Result<T, BackendError>) -> Void)?) -> URLSessionTask?
}

class JSONAPI: JSONHTTPRequestable {
    
    @discardableResult
    func request<T>(method: HTTPMethod,
                       baseURL: URL,
                       resource: String = "/",
                       headers: [String : String]? = nil,
                       params: [String: Any]? = nil,
                       completion: ((Result<T, BackendError>) -> Void)?) -> URLSessionTask? where T : Decodable {
        
        return requestData(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: nil, completion: encodeResponse(completion: completion))
    }
    
    @discardableResult
    func request<T, U>(method: HTTPMethod,
                       baseURL: URL,
                       resource: String = "/",
                       headers: [String : String]? = nil,
                       params: [String: Any]? = nil,
                       body: U,
                       completion: ((Result<T, BackendError>) -> Void)?) -> URLSessionTask? where T : Decodable, U : Encodable {
        
        do {
            let data = try JSONEncoder().encode(body)
            let encodeCompletion = encodeResponse(completion: completion)
            return requestData(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: data, completion: encodeCompletion)
        } catch {
            completion?(.failure(.invalidRequest))
            return nil
        }
    }
    
    private func encodeResponse<T: Decodable>(completion: ((Result<T, BackendError>) -> Void)?) -> ((Result<Data?, BackendError>) -> Void) {
        return { (result: Result<Data?, BackendError>) in
            switch result {
            case .success(let data):
                guard let data = data else {
                    completion?(.failure(.invalidResponse))
                    return
                }
                
                let decoder = JSONDecoder()
                do {
                    let object = try decoder.decode(T.self, from: data)
                    completion?(.success(object))
                } catch {
                    completion?(.failure(.invalidResponse))
                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    private func requestData(method: HTTPMethod = .GET, baseURL: URL, resource: String = "/", headers: [String: String]? = nil, params: [String: Any]? = nil, body: Data? = nil, completion: ((Result<Data?, BackendError>) -> Void)?) -> URLSessionTask? {
        
        let resourceURL = baseURL.appendingPathComponent(resource)
        
        guard var urlComponents = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
            completion?(.failure(.invalidRequest))
            return nil
        }
        
        if let params = params,
            method == .GET {
            urlComponents.queryItems = params.compactMap ({ (arg) -> URLQueryItem in
                let (key, value) = arg
                return URLQueryItem(name: key, value: String(describing: value))
            })
        }
        
        guard let url = urlComponents.url else {
            completion?(.failure(.invalidRequest))
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion?(.failure(.underlying(error)))
                return
            }
            
            guard let response = response as? HTTPURLResponse,
                response.statusCode == 200 else {
                    completion?(.failure(.notReachable))
                    return
            }
            
            completion?(.success(data))
        }
        task.resume()
        
        return task
    }
}
