//
//  JSONAPI
//
//  Created by Andreas Ganske on 16.03.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import Result

public class JSONAPI: API {
    
    var requester: SynchronousRequester
    
    public init(requester: SynchronousRequester = URLSession.shared) {
        self.requester = requester
    }

    public func trigger<U>(method: HTTPMethod,
                           baseURL: URL,
                           resource: String = "/",
                           headers: [String : String]? = nil,
                           params: [String: Any]? = nil,
                           body: U? = nil,
                           decorator: ((inout URLRequest) -> Void)? = nil,
                           completion: @escaping ((APIError?) -> Void)) where U: Encodable {
        
        let queue = OperationQueue.current?.underlyingQueue
        let threadCompletion = { (result: APIError?) in
            queue?.async {
                completion(result)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try body.flatMap({ (body) -> Data in
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    return try encoder.encode(body)
                })
                var request = try self.request(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: data)
                decorator?(&request)
                let (_, response) = try self.requester.synchronousDataTask(with: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode) else {
                        throw APIError.notReachable
                }
                
                threadCompletion(nil)
            } catch (let error as APIError) {
                threadCompletion(error)
            } catch {
                threadCompletion(APIError.underlying(error))
            }
        }
    }
    
    public func retrieve<T, U>(method: HTTPMethod,
                               baseURL: URL,
                               resource: String = "/",
                               headers: [String : String]? = nil,
                               params: [String: Any]? = nil,
                               body: U? = nil,
                               decorator: ((inout URLRequest) -> Void)? = nil,
                               completion: @escaping ((Result<T, APIError>) -> Void)) where T: Decodable, U: Encodable {
        
        let queue = OperationQueue.current?.underlyingQueue
        let threadCompletion = { (result: Result<T, APIError>) in
            queue?.async {
                completion(result)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try body.flatMap({ (body) -> Data in
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    return try encoder.encode(body)
                })
                var request = try self.request(method: method, baseURL: baseURL, resource: resource, headers: headers, params: params, body: data)
                decorator?(&request)
                
                let (receivedData, response) = try self.requester.synchronousDataTask(with: request)
                
                guard let responseData = receivedData else {
                    throw APIError.invalidResponse
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode) else {
                        throw APIError.notReachable
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let object = try decoder.decode(T.self, from: responseData)
                
                threadCompletion(.success(object))
            } catch (let error as APIError) {
                threadCompletion(.failure(error))
            } catch {
                threadCompletion(.failure(APIError.underlying(error)))
            }
        }
    }
    
    public func request(method: HTTPMethod = .GET,
                        baseURL: URL,
                        resource: String = "/",
                        headers: [String: String]? = nil,
                        params: [String: Any]? = nil,
                        body: Data? = nil) throws -> URLRequest {
        
        let resourceURL = baseURL.appendingPathComponent(resource)
        
        guard var urlComponents = URLComponents(url: resourceURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        
        if let params = params {
            urlComponents.queryItems = params.compactMap ({ (arg) -> URLQueryItem in
                let (key, value) = arg
                let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                return URLQueryItem(name: key, value: encodedValue)
            })
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidRequest
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
