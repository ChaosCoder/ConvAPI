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
    
    struct Empty: Codable {}
    
    struct Post: Codable, Equatable {
        let name: String
    }
    
    func testPostWithEmptyResponse() {
        let api = JSONAPI() as API
        let url = URL(string: "https://httpbin.org")!
        
        let expect = self.expectation(description: "Completion")
        api.trigger(method: HTTPMethod.POST, baseURL: url, resource: "/status/200") { (error: BackendError?) in
            XCTAssertNil(error)
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: 10)
    }
    
    func testPost() {
        let api = JSONAPI()
        
        let post = Post(name: "test")
        let url = URL(string: "https://putsreq.com")!
        
        let expect = self.expectation(description: "Completion")
        api.retrieve(method: HTTPMethod.POST, baseURL: url, resource: "/2AqxIseyzrby33355GBr", body: post) { (result: Result<Post, BackendError>) in
            if case let .success(retrieved) = result {
                XCTAssertEqual(retrieved, post)
                expect.fulfill()
            }
        }
        
        wait(for: [expect], timeout: 10)
    }
    
    func testGet() {
        let api = JSONAPI()
        
        let url = URL(string: "https://putsreq.com")!
        let post = Post(name: "test")
        let params: [String: Any] = ["name": "test"]
        let expect = self.expectation(description: "Completion")
        
        api.retrieve(method: HTTPMethod.GET, baseURL: url, resource: "/2AqxIseyzrby33355GBr", params: params) { (result: Result<Post, BackendError>) in
            if case let .success(retrieved) = result {
                XCTAssertEqual(retrieved, post)
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        wait(for: [expect], timeout: 10)
    }
    
}
