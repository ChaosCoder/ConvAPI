//
//  JSONAPITests.swift
//  JSONAPITests
//
//  Created by Andreas Ganske on 15.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import XCTest
import Result
@testable import JSONAPI

struct MockRequester: AsynchronousRequester {
    let callback: (URLRequest) -> Void
    
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        callback(request)
        return URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
    }
}

struct EmptyAPIResponse: Codable, Empty {}

struct APIError: Codable, Error {
    let code: Int
    let message: String
}

typealias APIResult<T> = Result<T, RequestError<APIError>> where T: Codable

class JSONAPITests: XCTestCase {
    
    let api = JSONAPI()
    let url = URL(string: "https://jsonapitestserver.herokuapp.com")!
    
    struct Post: Codable, Equatable {
        let name: String
    }
    
    func testPostWithEmptyResponse() {
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post") { (error: RequestError<APIError>?) in
            XCTAssertNil(error)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testInternalServerError() {
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/get", headers: ["X-HTTP-STATUS": "500"]) { (error: RequestError<APIError>?) in
            XCTAssertNotNil(error)
            guard case .some(.invalidJSONResponse(let statusCode, _)) = error else {
                return XCTFail()
            }
            XCTAssertEqual(statusCode, 500)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testBadRequestError() {
        let expectedError = APIError(code: 1, message: "Test")
        
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", headers: ["X-HTTP-STATUS": "400"], body: expectedError) { (requestError: RequestError<APIError>?) in
            XCTAssertNotNil(requestError)
            guard case .some(.applicationError(let error)) = requestError else {
                return XCTFail()
            }
            XCTAssertEqual(error.code, 1)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testPost() {
        let post = Post(name: "example")
        
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", body: post) { (result: APIResult<Post>) in
            if case let .success(object) = result {
                XCTAssertEqual(object, post)
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testGet() {
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        
        api.request(method: .GET, baseURL: url, resource: "/get?name=test") { (result: APIResult<Post>) in
            if case let .success(object) = result {
                XCTAssertEqual(object, post)
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testBadRequest() {
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/get", headers: ["X-HTTP-STATUS": "400"]) { (result: APIResult<Post>) in
            if case .success(_) = result { XCTFail() }
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testComplexRedirection() {
        let headers = ["X-LOCATION": "https://jsonapitestserver.herokuapp.com/get?name=test"]
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/redirect", headers: headers) { (result: APIResult<Post>) in
            if case let .success(object) = result {
                XCTAssertEqual(object, post)
            } else {
                XCTFail()
            }
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testContentTypeHeader() {
        let expect = self.expectation(description: "Completion")
        let mockRequester = MockRequester { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            expect.fulfill()
        }
        
        let api = JSONAPI(requester: mockRequester)
        api.request(method: .GET, baseURL: url) { (_: RequestError<APIError>?) in }
        wait(for: [expect], timeout: 5)
    }
}
