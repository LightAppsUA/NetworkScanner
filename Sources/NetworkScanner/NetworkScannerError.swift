//
//  NetworkScannerError.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 22.05.2024.
//

import Foundation

public enum NetworkScannerError: Error {
    case permissionDenied
    case noNetwork
}

extension NetworkScannerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .permissionDenied:
            return "Permission denied"
        case .noNetwork:
            return "No network connection"
        }
    }
}
