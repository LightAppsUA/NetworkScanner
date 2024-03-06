//
//  Device.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 06.03.2024.
//

import Foundation

public enum DeviceType {
    case regular, router, airPlay, googleCast, appleDevice
}

public struct Device {
    public var name: String
    public var host: String
    public var macAddress: String?
    public var model: String?
    public var type: DeviceType = .regular
}
