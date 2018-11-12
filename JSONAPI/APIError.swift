//
//  APIError.swift
//  JSONAPI
//
//  Created by Andreas Ganske on 19.04.18.
//  Copyright © 2018 Andreas Ganske. All rights reserved.
//

import Foundation

public struct APIError: Error, Equatable {

    let type: ErrorType
    let description: String

    public enum ErrorType: String, Codable {
        case unknown
        case test
    }
}

extension APIError: Codable {

    enum CodingKeys: String, CodingKey {
        case type
        case description
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let errorTypeString = try values.decode(String.self, forKey: .type)
        let description = try values.decode(String.self, forKey: .description)

        self.init(type: ErrorType(rawValue: errorTypeString) ?? .unknown, description: description)
    }
}
