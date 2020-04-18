//
//  Empty.swift
//  ConveyPI
//
//  Created by Andreas Ganske on 18.04.20.
//  Copyright © 2020 Andreas Ganske. All rights reserved.
//

import Foundation

public protocol Empty: Codable {
    init()
}

public struct EmptyResponse: Empty {
    public init() {}
}
