//
//  NWBrowser.Result.Metadata+info.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Network

extension NWBrowser.Result.Metadata {
    var info: [String: String] {
        switch self {
        case let .bonjour(record):
            record.dictionary
        default:
            [:]
        }
    }
}
