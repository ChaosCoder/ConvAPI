//
//  JSONAPI
//
//  Created by Andreas Ganske on 16.03.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

public enum BackendError: Error {
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

private struct Empty: Encodable {}

public protocol API {
    
    func trigger<U>(method: HTTPMethod,
                    baseURL: URL,
                    resource: String,
                    headers: [String : String]?,
                    params: [String: Any]?,
                    body: U,
                    completion: @escaping ((BackendError?) -> Void)) where U: Encodable
    
    func retrieve<T, U>(method: HTTPMethod,
                        baseURL: URL,
                        resource: String,
                        headers: [String : String]?,
                        params: [String: Any]?,
                        body: U,
                        completion: @escaping ((Result<T, BackendError>) -> Void)) where T: Decodable, U: Encodable
}

public extension API {
    
    func trigger(method: HTTPMethod,
                 baseURL: URL,
                 resource: String = "/",
                 headers: [String : String]? = nil,
                 params: [String: Any]? = nil,
                 completion: @escaping ((BackendError?) -> Void)) {
        trigger(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: Empty(), completion: completion)
    }
    
    func retrieve<T>(method: HTTPMethod,
                     baseURL: URL,
                     resource: String = "/",
                     headers: [String : String]? = nil,
                     params: [String: Any]? = nil,
                     completion: @escaping ((Result<T, BackendError>) -> Void)) where T: Decodable {
        retrieve(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: Empty(), completion: completion)
    }
}

public class JSONAPI: API {
    
    var urlSession: URLSession
    
    public init(urlSession: URLSession = URLSession.shared) {
        self.urlSession = urlSession
    }
    
    public func trigger<U>(method: HTTPMethod,
                           baseURL: URL,
                           resource: String = "/",
                           headers: [String : String]? = nil,
                           params: [String: Any]? = nil,
                           body: U,
                           completion: @escaping ((BackendError?) -> Void)) where U: Encodable {
        
        let queue = OperationQueue.current?.underlyingQueue
        let threadCompletion = { (result: BackendError?) in
            queue?.async {
                completion(result)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(body)
                let _ = try self.request(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: data)
                threadCompletion(nil)
            } catch (let error as BackendError) {
                threadCompletion(error)
            } catch {
                threadCompletion(BackendError.underlying(error))
            }
        }
    }
    
    public func retrieve<T, U>(method: HTTPMethod,
                               baseURL: URL,
                               resource: String = "/",
                               headers: [String : String]? = nil,
                               params: [String: Any]? = nil,
                               body: U,
                               completion: @escaping ((Result<T, BackendError>) -> Void)) where T: Decodable, U: Encodable {
        
        let queue = OperationQueue.current?.underlyingQueue
        let threadCompletion = { (result: Result<T, BackendError>) in
            queue?.async {
                completion(result)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let bodyData = try encoder.encode(body)
                
                let response = try self.request(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: bodyData)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let object = try decoder.decode(T.self, from: response)
                
                threadCompletion(.success(object))
            } catch (let error as BackendError) {
                threadCompletion(.failure(error))
            } catch {
                threadCompletion(.failure(BackendError.underlying(error)))
            }
        }
    }
    
    public func request(method: HTTPMethod = .GET,
                        baseURL: URL,
                        resource: String = "/",
                        headers: [String: String]? = nil,
                        params: [String: Any]? = nil,
                        body: Data? = nil) throws -> Data {
        
        let resourceURL = baseURL.appendingPathComponent(resource)
        
        guard var urlComponents = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidRequest
        }
        
        if let params = params {
            urlComponents.queryItems = params.compactMap ({ (arg) -> URLQueryItem in
                let (key, value) = arg
                return URLQueryItem(name: key, value: String(describing: value))
            })
        }
        
        guard let url = urlComponents.url else {
            throw BackendError.invalidRequest
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let (receivedData, response) = try urlSession.synchronousDataTask(with: request)
        
        guard let data = receivedData else {
            throw BackendError.invalidResponse
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
                throw BackendError.notReachable
        }
        
        return data
    }
}
