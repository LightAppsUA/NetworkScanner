//
//  NetworkScanner.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation
import Network
import NetworkScannerInternal

public class NetworkScanner: NSObject {
    private lazy var localNetworkAuthorization = LocalNetworkAuthorization()
    private var devices: [NetworkDevice] = []
    private var appleDevices: [NetworkDevice] = []
    private var airPlayDevices: [NetworkDevice] = []
    private var googleCastDevices: [NetworkDevice] = []

    public weak var delegate: NetworkScannerDelegate?

    private var combinedDevices: [NetworkDevice] {
        var results = devices

        for (index, device) in results.enumerated() {
            if let appleDevice = appleDevices.first(where: { $0.host == device.host }) {
                results[index].macAddress = appleDevice.macAddress
                results[index].name = appleDevice.name
                results[index].type = .appleDevice
            }

            if let airPlayDevice = airPlayDevices.first(where: { $0.host == device.host }) {
                results[index].macAddress = airPlayDevice.macAddress
                results[index].model = airPlayDevice.model
                results[index].name = airPlayDevice.name
                results[index].type = .airPlay
            }

            if let googleCastDevice = googleCastDevices.first(where: { $0.host == device.host }) {
                results[index].name = googleCastDevice.name
                results[index].model = googleCastDevice.model
                results[index].type = .googleCast
            }
        }

        return results
    }

    private var timer: Timer?

    private let appleServiceBrowser = AppleServiceBrowser()
    private let airPlayServiceBrowser = AirPlayServiceBrowser()
    private let googleCastServiceBrowser = GoogleCastServiceBrowser()

    private var operationQueue: OperationQueue?

    public func stop() {
        operationQueue?.cancelAllOperations()
        operationQueue = nil

        timer?.invalidate()
        timer = nil

        appleServiceBrowser.stop()
        airPlayServiceBrowser.stop()
        googleCastServiceBrowser.stop()

        resetData()
    }

    private func resetData() {
        appleDevices = []
        airPlayDevices = []
        googleCastDevices = []
        devices = []
    }

    public func start() {
        stop()

        localNetworkAuthorization.requestAuthorization { status in
            if status {
                let ipAddress = Self.getLocalIPAddress()
                let mask = Self.getLocalNetmask()
                let routerIP = NetworkHelper.getRouterIP()

                self.appleServiceBrowser.deviceDiscovered = { device in
                    var copyDevice = device
                    if copyDevice.host == "127.0.0.1" {
                        copyDevice.host = ipAddress
                    }

                    self.appleDevices.append(copyDevice)
                }

                self.airPlayServiceBrowser.deviceDiscovered = { device in
                    var copyDevice = device
                    if copyDevice.host == "127.0.0.1" {
                        copyDevice.host = ipAddress
                    }

                    self.airPlayDevices.append(copyDevice)
                }

                self.googleCastServiceBrowser.deviceDiscovered = { device in
                    var copyDevice = device
                    if copyDevice.host == "127.0.0.1" {
                        copyDevice.host = ipAddress
                    }

                    self.googleCastDevices.append(copyDevice)
                }

                self.appleServiceBrowser.search()
                self.airPlayServiceBrowser.search()
                self.googleCastServiceBrowser.search()

                let ips = self.ipRange(ipAddress: ipAddress, subnetMask: mask)

                var completedOperations = 0

                DispatchQueue.global(qos: .userInitiated).async {
                    let operationQueue = OperationQueue()

                    self.operationQueue = operationQueue

                    operationQueue.qualityOfService = .userInteractive

                    let operations = ips.map { ip in
                        let operation = PingOperation(host: ip)

                        operation.completionBlock = { [weak self] in
                            guard let self else { return }

                            if operation.isReachable {
                                devices.append(NetworkDevice(name: ip, host: ip, type: ip == routerIP ? .router : .regular))
                            }

                            completedOperations += 1

                            DispatchQueue.main.async {
                                self.delegate?.networkScannerDidUpdateProgress(currentIndex: completedOperations, totalCount: ips.count)
                            }
                        }

                        return operation
                    }

                    operationQueue.addOperations(operations, waitUntilFinished: true)

                    DispatchQueue.main.async {
                        self.delegate?.networkScannerDidFinishScanning(devices: self.combinedDevices)
                    }
                }
            }
        }
    }

    private func ipRange(ipAddress: String, subnetMask: String) -> [String] {
        let ipComponents = ipAddress.split(separator: ".").compactMap { UInt8($0) }
        let maskComponents = subnetMask.split(separator: ".").compactMap { UInt8($0) }

        guard ipComponents.count == 4, maskComponents.count == 4 else {
            return []
        }

        var networkAddress: [UInt8] = zip(ipComponents, maskComponents).map { $0 & $1 }
        var broadcastAddress: [UInt8] = zip(ipComponents, maskComponents).map { $0 | ~$1 }

        // Exclude network and broadcast addresses
        networkAddress[3] += 1
        broadcastAddress[3] -= 1

        var ips: [String] = []
        for a in networkAddress[0] ... broadcastAddress[0] {
            for b in networkAddress[1] ... broadcastAddress[1] {
                for c in networkAddress[2] ... broadcastAddress[2] {
                    for d in networkAddress[3] ... broadcastAddress[3] {
                        ips.append("\(a).\(b).\(c).\(d)")
                    }
                }
            }
        }

        return ips
    }

    public static func getLocalIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name = String(cString: interface.ifa_name)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }

            freeifaddrs(ifaddr)
        }

        return address ?? ""
    }

    public static func getLocalNetmask() -> String {
        var netmask: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name = String(cString: interface.ifa_name)
                    if name == "en0" {
                        var netmaskAddress = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_netmask, socklen_t(interface.ifa_netmask.pointee.sa_len), &netmaskAddress, socklen_t(netmaskAddress.count), nil, socklen_t(0), NI_NUMERICHOST)
                        netmask = String(cString: netmaskAddress)
                    }
                }
            }

            freeifaddrs(ifaddr)
        }

        return netmask ?? ""
    }
}
