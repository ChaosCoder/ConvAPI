//
//  AsynchronousRequester.swift
//  ConvAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation
import PromiseKit
#if canImport(PMKFoundation)
import PMKFoundation
#endif

public protocol AsynchronousRequester {
    func dataTask(_: PMKNamespacer, with convertible: URLRequestConvertible) -> Promise<(data: Data, response: URLResponse)>
}

extension URLSession: AsynchronousRequester {}
