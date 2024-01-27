# ConvAPI 
[![](http://img.shields.io/badge/Swift-5.0-blue.svg)]() [![](http://img.shields.io/badge/iOS-15.0%2B-blue.svg)]() [![](https://img.shields.io/github/license/ChaosCoder/ConvAPI.svg)](LICENSE.md) [![Build Status](https://app.bitrise.io/app/9bd0d2e769e903f9/status.svg?token=9IwhtVc_5lq3l5PnCY9LLQ&branch=master)](https://app.bitrise.io/app/9bd0d2e769e903f9)

ConvAPI allows easy [HTTP](https://tools.ietf.org/html/rfc7231) requests in [Swift](https://swift.org) against [REST](https://en.wikipedia.org/wiki/Representational_state_transfer)-style [APIs](https://en.wikipedia.org/wiki/Application_programming_interface) with [JSON](https://www.json.org/) formatting by supporting [codable](https://developer.apple.com/documentation/swift/codable) bodies and [promised](https://github.com/mxcl/PromiseKit) responses.

## Etymology
ConvAPI (`/kənˈveɪ-piː-aɪ/`) is a contraction of **Convey** (*to carry, bring, or take from one place to another*) and **API** (*Application Programming Interface*).

## Usage

ConvAPI has the method
```swift
func request<T, U, E>(method: APIMethod,
                      baseURL: URL,
                      resource: String,
                      headers: [String: String]?,
                      params: [String: Any]?,
                      body: T?,
                      error: E.Type,
                      decorator: ((inout URLRequest) -> Void)?) async throws -> U
```
where `T: Encodable, U: Decodable, E: (Error & Decodable)` at its core.

This method allows you to asynchronously request a resource from an API specifying the 
- method (*e.g. `GET`*),
- baseURL,
- resource URI (*e.g. `/users/42`*),
- http headers as a dictionary, 
- query params as a dictionary, 
- request body (any type that conforms to `Encodable`),
- an error struct (`Decodable`) your API might respond with and,
- a decorator to access/alter the `URLRequest` that gets fired underneath

and getting the response with a type (`U`) conforming to `Decodable`. All of the error handling (*status code, empty response, etc.*) and parsing is done for you.

### Requesting a resource

Request a resource by specifying 

```swift
struct User: Codable {
    let id: Int
    let name: String
}
        
let api = ConvAPI()
let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
let user: User = try await api.request(method: .GET, baseURL: baseURL, resource: "/users/1", error: ConvAPIError.self)
print(user) // User(id: 1, name: "Leanne Graham")
```

### Specifying an error

If your API has an error JSON it is responsing with, just define your error response and hand it in:

```swift
struct MyAPIError: Error, Codable {
    let code: Int
    let message: String
}

do {
    let user: User = try await api.request(method: .GET, baseURL: baseURL, resource: "/users/1", error: MyAPIError.self)
    // [...]
} catch {
    switch error {
        case let error as MyAPIError: print(error.code)
        default: break // Request error, network down, etc.
    }
}
```

### Swift Package Manager

```swift
.package(url: "https://github.com/ChaosCoder/ConvAPI.git", from: "1.0.0")
```
