//
//  URLSession+Synchronous.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 17.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation

extension URLSession {
    public func synchronousDataTask(with urlRequest: URLRequest) throws -> (Data?, URLResponse?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        let dataTask = self.dataTask(with: urlRequest) {
            data = $0
            response = $1
            error = $2
            
            semaphore.signal()
        }
        dataTask.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = error {
            throw error
        }
        
        return (data, response)
    }
}
