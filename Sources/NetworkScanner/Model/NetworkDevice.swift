//
//  NetworkDevice.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation

public enum NetworkDeviceType {
    case regular, router, airPlay, googleCast, appleDevice
}

public struct NetworkDevice {
    public var name: String
    public var host: String
    public var macAddress: String?
    public var model: String?
    public var type: NetworkDeviceType = .regular
}
