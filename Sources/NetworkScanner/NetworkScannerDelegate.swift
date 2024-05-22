//
//  NetworkScannerDelegate.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation

public protocol NetworkScannerDelegate: AnyObject {
    func networkScannerDidFinishScanning(devices: [NetworkDevice])
    func networkScannerDidUpdateProgress(currentIndex: Int, totalCount: Int)
    func networkScannerFailed(error: Error)
}
