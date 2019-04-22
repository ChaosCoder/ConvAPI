//
//  JSONAPITests.swift
//  JSONAPITests
//
//  Created by Andreas Ganske on 15.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import XCTest
import PromiseKit
@testable import JSONAPI

struct MockRequester: AsynchronousRequester {
    let callback: (URLRequest) -> Void
    
    func dataTask(_ namespace: PMKNamespacer, with convertible: URLRequestConvertible) -> Promise<(data: Data, response: URLResponse)> {
        let request = convertible.pmkRequest
        callback(request)
        return URLSession.shared.dataTask(namespace, with: convertible)
    }
    
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

class JSONAPITests: XCTestCase {

    let url = URL(string: "https://jsonapitestserver.herokuapp.com")!

    lazy var api: JSONAPI = {
        return JSONAPI(requester: URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue()))
    }()

    struct Post: Codable, Equatable {
        let name: String
    }
    
    struct PostWithDate: Codable, Equatable {
        let name: String
        let date: Date
    }
    
    func testPostWithEmptyResponse() {
        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", error: APIError.self).done { _ in
            expect.fulfill()
        }.cauterize()
        wait(for: [expect], timeout: 5)
    }

    func testInternalServerError() {
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/get", headers: ["X-HTTP-STATUS": "500"], error: APIError.self).done { (_: Post) in
            XCTFail()
        }.catch { error in
            expect.fulfill()
        }

        wait(for: [expect], timeout: 5)
    }

    func testErrorDescription() {
        let error: Error = RequestError.invalidRequest
        XCTAssertEqual(error.localizedDescription, "Invalid request")
    }

    func testBadRequestError() {
        let expectedError = APIError(code: 1, message: "Test")

        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", headers: ["X-HTTP-STATUS": "400"], body: expectedError, error: APIError.self).catch { (error) in
            switch error {
            case let error as APIError:
                XCTAssertEqual(error.code, expectedError.code)
                XCTAssertEqual(error.message, expectedError.message)
                expect.fulfill()
            default:
                XCTFail()
            }
        }

        wait(for: [expect], timeout: 5)
    }

    func testNonBlockingBehavior() {
        let post = Post(name: "example")

        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", body: post, error: APIError.self).then { (_: Post) in
            self.api.request(method:.POST, baseURL: self.url, resource: "/post", body: post, error: APIError.self).done { (_: Post) in
                expect.fulfill()
            }
        }.cauterize()

        wait(for: [expect], timeout: 10)
    }
    
    func testChaining() {
        let post = Post(name: "example")
        let expect = self.expectation(description: "Completion")
        
        api.request(method: .POST, baseURL: url, resource: "/post", body: post, error: APIError.self).then { (responsePost: Post) in
            self.api.request(method: .POST, baseURL: self.url, resource: "/post", body: responsePost, error: APIError.self)
        }.done { (responsePost: Post) in
            XCTAssertEqual(responsePost, post)
            expect.fulfill()
        }.cauterize()
        
        wait(for: [expect], timeout: 10)
    }
    
    func testWaitingForMultipleRequests() {
        let postOne = Post(name: "one")
        let postTwo = Post(name: "two")
        
        let expect = self.expectation(description: "Completion")
        
        let requestOne: Promise<Post> = api.request(method: .POST, baseURL: url, resource: "/post", body: postOne, error: APIError.self)
        let requestTwo: Promise<Post> = api.request(method: .POST, baseURL: url, resource: "/post", body: postTwo, error: APIError.self)
        
        when(fulfilled: requestOne, requestTwo).done { responseOne, responseTwo in
            XCTAssertEqual(responseOne, postOne)
            XCTAssertEqual(responseTwo, postTwo)
            expect.fulfill()
        }.cauterize()
        
        wait(for: [expect], timeout: 10)
    }

    func testPost() {
        let post = Post(name: "example")

        let expect = self.expectation(description: "Completion")
        api.request(method: .POST, baseURL: url, resource: "/post", body: post, error: APIError.self).done { (object: Post) in
            XCTAssertEqual(object, post)
            expect.fulfill()
        }.cauterize()

        wait(for: [expect], timeout: 5)
    }

    func testGet() {
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        
        api.request(method: .GET, baseURL: url, resource: "/get?name=test", error: APIError.self).done { (responsePost: Post) in
            XCTAssertEqual(responsePost, post)
            expect.fulfill()
        }.cauterize()

        wait(for: [expect], timeout: 5)
    }

    func testBadRequest() {
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/get", headers: ["X-HTTP-STATUS": "400"], error: APIError.self).done { (post: Post) in
            XCTFail()
        }.catch { _ in
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }

    func testComplexRedirection() {
        let headers = ["X-LOCATION": "https://jsonapitestserver.herokuapp.com/get?name=test"]
        let post = Post(name: "test")
        let expect = self.expectation(description: "Completion")
        api.request(method: .GET, baseURL: url, resource: "/redirect", headers: headers, error: APIError.self).done { (responsePost: Post) in
            XCTAssertEqual(responsePost, post)
            expect.fulfill()
        }.cauterize()
        wait(for: [expect], timeout: 5)
    }

    func testContentTypeHeader() {
        let expect = self.expectation(description: "Completion")
        let mockRequester = MockRequester { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            expect.fulfill()
        }

        let api = JSONAPI(requester: mockRequester)
        api.request(method: .GET, baseURL: url, error: APIError.self).cauterize()
        wait(for: [expect], timeout: 5)
    }

    func test8601DateEncoding() {

        struct RawPostWithDate: Codable {
            let name: String
            let date: String
        }

        let expect = self.expectation(description: "Completion")
        let mockRequester = MockRequester { request in
            let body = request.httpBody!
            let decoded = try! JSONDecoder().decode(RawPostWithDate.self, from: body)
            XCTAssertEqual(decoded.date, "2019-01-18T12:10:28Z")
            expect.fulfill()
        }

        let post = PostWithDate(name: "Test", date: Date(timeIntervalSince1970: 1547813428))
        let api = JSONAPI(requester: mockRequester)
        api.request(method: .POST, baseURL: url, body: post, error: APIError.self).cauterize()
        wait(for: [expect], timeout: 5)
    }

    func testAlternativeDateEncoding() {

        struct RawPostWithDate: Codable {
            let name: String
            let date: TimeInterval
        }

        let secondsSince1970: TimeInterval = 1547813428
        let expect = self.expectation(description: "Completion")
        let mockRequester = MockRequester { request in
            let body = request.httpBody!
            let decoded = try! JSONDecoder().decode(RawPostWithDate.self, from: body)
            XCTAssertEqual(decoded.date, secondsSince1970)
            expect.fulfill()
        }

        let post = PostWithDate(name: "Test", date: Date(timeIntervalSince1970: secondsSince1970))
        let api = JSONAPI(requester: mockRequester)
        api.encoder.dateEncodingStrategy = .secondsSince1970
        api.request(method: .POST, baseURL: url, body: post, error: APIError.self).cauterize()
        wait(for: [expect], timeout: 5)
    }

    func testCallDecorator() {
        let expect = self.expectation(description: "Decorator called")
        api.request(method: .POST, baseURL: url, resource: "/post", error: APIError.self, decorator: { request in
            expect.fulfill()
        }).cauterize()
        wait(for: [expect], timeout: 5)
    }
}

