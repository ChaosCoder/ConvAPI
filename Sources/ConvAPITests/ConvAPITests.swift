//
//  ConvAPITests.swift
//  ConvAPITests
//
//  Created by Andreas Ganske on 15.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import XCTest
@testable import ConvAPI

struct MockRequester: AsynchronousRequester {
    let callback: (URLRequest) -> Void
    
    func data(for request: URLRequest, delegate: (URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        callback(request)
        return try await URLSession.shared.data(for: request)
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

class ConvAPITests: XCTestCase {

    static let url = URL(string: "http://localhost:1337")!

    lazy var api: ConvAPI = {
        return ConvAPI(requester: URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue()))
    }()

    struct Post: Codable, Equatable {
        let name: String
    }
    
    struct PostWithDate: Codable, Equatable {
        let name: String
        let date: Date
    }
    
    override class func setUp() {
        super.setUp()
        
        // Assert that the server is reachable
        let (_, response, error) = URLSession.shared.synchronousDataTask(with: ConvAPITests.url)
        assert((response as! HTTPURLResponse).statusCode == 200)
        assert(error == nil)
    }
    
    func testPostWithEmptyResponse() async throws {
        try await api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", error: APIError.self)
    }

    func testInternalServerError() async {
        do {
            let _: Post = try await api.request(method: .GET, baseURL: ConvAPITests.url, resource: "/get", headers: ["X-HTTP-STATUS": "500"], error: APIError.self)
            XCTFail()
        } catch {
            
        }
    }

    func testUsage() async throws {
        struct User: Codable {
            let id: Int
            let name: String
        }
        
        struct MyAPIError: Error, Codable {
            let code: Int
            let message: String
        }
        
        let api = ConvAPI()
        let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
        let user: User = try await api.request(method: .GET, baseURL: baseURL, resource: "/users/1", error: MyAPIError.self)
        print(user)
    }

    func testErrorDescription() {
        let error: Error = RequestError.invalidRequest
        XCTAssertEqual(error.localizedDescription, "Invalid request")
    }

    func testBadRequestError() async {
        let expectedError = APIError(code: 1, message: "Test")

        do {
            try await api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", headers: ["X-HTTP-STATUS": "400"], body: expectedError, error: APIError.self)
        } catch {
            switch error {
            case let error as APIError:
                XCTAssertEqual(error.code, expectedError.code)
                XCTAssertEqual(error.message, expectedError.message)
            default:
                XCTFail()
            }
        }
    }

    func testNonBlockingBehavior() async throws {
        let postOne = Post(name: "one")
        let postTwo = Post(name: "two")

        async let post1: Post = api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", body: postOne, error: APIError.self)
        async let post2: Post = api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", body: postTwo, error: APIError.self)
        
        let posts = try await [post1, post2]
        
        XCTAssertEqual(posts, [postOne, postTwo])
    }

    func testPost() async throws {
        let post = Post(name: "example")
        let retrieved: Post = try await api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", body: post, error: APIError.self)
        XCTAssertEqual(retrieved, post)
    }

    func testGet() async throws {
        let post = Post(name: "test")
        let responsePost: Post = try await api.request(method: .GET, baseURL: ConvAPITests.url, resource: "/get?name=test", error: APIError.self)
        XCTAssertEqual(responsePost, post)
    }

    func testBadRequest() async throws {
        do {
            let _: Post = try await api.request(method: .GET, baseURL: ConvAPITests.url, resource: "/get", headers: ["X-HTTP-STATUS": "400"], error: APIError.self)
            XCTFail()
        } catch {
            
        }
    }

    func testComplexRedirection() async throws {
        let headers = ["X-LOCATION": "http://localhost:1337/get?name=test"]
        let post = Post(name: "test")
        let responsePost: Post = try await api.request(method: .GET, baseURL: ConvAPITests.url, resource: "/redirect", headers: headers, error: APIError.self)
        XCTAssertEqual(responsePost, post)
    }

    func testContentTypeHeader() async throws {
        let expect = self.expectation(description: "Completion")
        let mockRequester = MockRequester { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            expect.fulfill()
        }

        let api = ConvAPI(requester: mockRequester)
        try await api.request(method: .GET, baseURL: ConvAPITests.url, error: APIError.self)
        await fulfillment(of: [expect])
    }

    func test8601DateEncoding() async throws {

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
        let api = ConvAPI(requester: mockRequester)
        try await api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", body: post, error: APIError.self)
        await fulfillment(of: [expect])
    }

    func testAlternativeDateEncoding() async throws {

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
        let api = ConvAPI(requester: mockRequester)
        api.encoder.dateEncodingStrategy = .secondsSince1970
        try await api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", body: post, error: APIError.self)
        await fulfillment(of: [expect])
    }

    func testCallDecorator() async throws {
        let expect = self.expectation(description: "Decorator called")
        try await api.request(method: .POST, baseURL: ConvAPITests.url, resource: "/post", error: APIError.self, decorator: { request in
            expect.fulfill()
        })
        await fulfillment(of: [expect])
    }
}

