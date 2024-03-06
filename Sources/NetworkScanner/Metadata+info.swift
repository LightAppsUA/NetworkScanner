//
//  Metadata+info.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 06.03.2024.
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
