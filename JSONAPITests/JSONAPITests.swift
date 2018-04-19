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

class JSONAPITests: XCTestCase {
    
    struct Post: Codable, Equatable {
        let name: String
    }
    
    func testPostWithEmptyResponse() {
        let api = JSONAPI()
        let url = URL(string: "https://httpbin.org")!
        
        let expect = self.expectation(description: "Completion")
        api.trigger(method: HTTPMethod.POST, baseURL: url, resource: "/status/200") { (error: APIError?) in
            XCTAssertNil(error)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testPost() {
        let api = JSONAPI()
        
        let post = Post(name: "test")
        let url = URL(string: "https://putsreq.com")!
        
        let expect = self.expectation(description: "Completion")
        api.retrieve(method: HTTPMethod.POST, baseURL: url, resource: "/2AqxIseyzrby33355GBr", body: post) { (result: Result<Post, APIError>) in
            if case let .success(retrieved) = result {
                XCTAssertEqual(retrieved, post)
                expect.fulfill()
            }
        }
        
        wait(for: [expect], timeout: 5)
    }
    
    func testGet() {
        let api = JSONAPI()
        
        let url = URL(string: "https://putsreq.com")!
        let post = Post(name: "test")
        let params: [String: Any] = ["name": "test"]
        let expect = self.expectation(description: "Completion")
        
        api.retrieve(method: HTTPMethod.GET, baseURL: url, resource: "/2AqxIseyzrby33355GBr", params: params) { (result: Result<Post, APIError>) in
            if case let .success(retrieved) = result {
                XCTAssertEqual(retrieved, post)
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testSynchronousURLTask() {
        let session = URLSession.shared
        let url = URL(string: "https://httpbin.org/status/204")!
        let urlRequest = URLRequest(url: url)
        let (data, response) = try! session.synchronousDataTask(with: urlRequest)
        XCTAssert(response is HTTPURLResponse)
        XCTAssertEqual((response as! HTTPURLResponse).statusCode, 204)
        XCTAssertNotNil(data)
    }
    
    func testBadRequestRaw() {
        let api = JSONAPI()
        let url = URL(string: "https://httpbin.org")!
        let resource = "/status/400"
        let data = try? api.request(method: .GET, baseURL: url, resource: resource, headers: nil, params: nil, body: nil)
        XCTAssertNil(data)
    }
    
    func testBadRequest() {
        let api = JSONAPI()
        let url = URL(string: "https://httpbin.org")!
        let resource = "/status/400"
        let expect = self.expectation(description: "Completion")
        api.retrieve(method: .GET, baseURL: url, resource: resource) { (result: Result<Post, APIError>) in
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }
    
    func testComplexRedirection() {
        let api = JSONAPI()
        
        let url = URL(string: "https://httpbin.org")!
        let resource = "/redirect-to"
        let params: [String: Any] = ["url": "https://putsreq.com/2AqxIseyzrby33355GBr?name=test"]
        
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        api.retrieve(method: HTTPMethod.GET, baseURL: url, resource: resource, params: params) { (result: Result<Post, APIError>) in
            if case let .success(retrieved) = result {
                XCTAssertEqual(retrieved, post)
            } else {
                XCTFail()
            }
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }
}
