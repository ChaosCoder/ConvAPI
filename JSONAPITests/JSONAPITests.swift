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

struct EmptyAPIResponse: Codable {}

typealias EmptyAPIResult = Result<EmptyAPIResponse, RequestError<APIError>>
typealias APIResult<T> = Result<T, RequestError<APIError>> where T: Codable

class JSONAPITests: XCTestCase {
    
    struct Post: Codable, Equatable {
        let name: String
    }
    
    func testPostWithEmptyResponse() {
        let api = JSONAPI()
        let url = URL(string: "https://httpbin.org")!
        let response = EmptyAPIResponse()
        
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", body: response) { (response: EmptyAPIResult) in
            guard case .success(_) = response else { return XCTFail() }
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testInternalServerError() {
        let api = JSONAPI()
        let url = URL(string: "https://httpbin.org")!
        
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/status/500") { (response: EmptyAPIResult) in
            if case .failure(let receivedError) = response,
                case .invalidJSONResponse(let statusCode, _) = receivedError {
                XCTAssertEqual(statusCode, 500)
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testBadRequestError() {
        let api = JSONAPI()
        let url = URL(string: "https://putsreq.com")!
        let expectedError = APIError.init(type: .test, description: "Test")
        
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/doZHFUeg6eYyongfpTZg", headers: ["X-HTTP-STATUS": "400"], body: expectedError) { (response: EmptyAPIResult) in
            if case .failure(let requestError) = response,
                case .applicationError(let error) = requestError {
                XCTAssertEqual(error.type, .test)
            } else {
                XCTFail()
            }
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testPost() {
        let api = JSONAPI()
        
        let post = Post(name: "example")
        let url = URL(string: "https://putsreq.com")!
        
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/UacIEbxTHVIVaHDho9hu", body: post) { (result: APIResult<Post>) in
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
        let api = JSONAPI()
        
        let url = URL(string: "https://putsreq.com")!
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        
        api.request(method: .GET, baseURL: url, resource: "/UacIEbxTHVIVaHDho9hu") { (result: APIResult<Post>) in
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
        let api = JSONAPI()
        let url = URL(string: "https://httpbin.org")!
        let resource = "/status/400"
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: resource) { (result: APIResult<Post>) in
            if case .success(_) = result { XCTFail() }
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testComplexRedirection() {
        let api = JSONAPI()
        
        let url = URL(string: "https://httpbin.org")!
        let resource = "/redirect-to"
        let params: [String: Any] = ["url": "https://putsreq.com/UacIEbxTHVIVaHDho9hu?name=test"]
        
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: resource, params: params) { (result: APIResult<Post>) in
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
        
        let url = URL(string: "https://example.org")!
        let api = JSONAPI(requester: mockRequester)
        api.request(method: .GET, baseURL: url) { (_: EmptyAPIResult) in }
        wait(for: [expect], timeout: 5)
    }
}
