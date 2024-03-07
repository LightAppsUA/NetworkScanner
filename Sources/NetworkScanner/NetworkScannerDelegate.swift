//
//  NetworkScannerDelegate.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 07.03.2024.
//

import Foundation

public protocol NetworkScannerDelegate: AnyObject {
    func networkScannerDidFinishScanning(devices: [NetworkDevice])
}
