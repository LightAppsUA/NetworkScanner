//
//  NetworkScanner.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 06.03.2024.
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
        var _devices = devices

        for (index, device) in _devices.enumerated() {
            if let appleDevice = appleDevices.first(where: { $0.host == device.host }) {
                _devices[index].macAddress = appleDevice.macAddress
                _devices[index].name = appleDevice.name
                _devices[index].type = .appleDevice
            }

            if let airPlayDevice = airPlayDevices.first(where: { $0.host == device.host }) {
                _devices[index].macAddress = airPlayDevice.macAddress
                _devices[index].model = airPlayDevice.model
                _devices[index].name = airPlayDevice.name
                _devices[index].type = .airPlay
            }

            if let googleCastDevice = googleCastDevices.first(where: { $0.host == device.host }) {
                _devices[index].name = googleCastDevice.name
                _devices[index].model = googleCastDevice.model
                _devices[index].type = .googleCast
            }
        }

        return _devices
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
                let ipAddress = self.getIPAddress()
                let mask = self.getNetmask()
                let routerIP = NetworkHelper.getRouterIP()

                self.appleServiceBrowser.deviceDiscovered = { device in
                    var copyDevice = device
                    if copyDevice.host == "127.0.0.1" {
                        copyDevice.host = ipAddress
                    }

                    self.appleDevices.append(copyDevice)
                }

                self.appleServiceBrowser.search()

                self.airPlayServiceBrowser.deviceDiscovered = { device in
                    var copyDevice = device
                    if copyDevice.host == "127.0.0.1" {
                        copyDevice.host = ipAddress
                    }

                    self.airPlayDevices.append(copyDevice)
                }

                self.airPlayServiceBrowser.search()

                self.googleCastServiceBrowser.deviceDiscovered = { device in
                    var copyDevice = device
                    if copyDevice.host == "127.0.0.1" {
                        copyDevice.host = ipAddress
                    }

                    self.googleCastDevices.append(copyDevice)
                }

                self.googleCastServiceBrowser.search()

                let ips = self.ipRange(ipAddress: ipAddress, subnetMask: mask)

                var startTime = Date().timeIntervalSince1970
                var completedOperations = 0

                DispatchQueue.global(qos: .userInitiated).async {
                    let operationQueue = OperationQueue()

                    self.operationQueue = operationQueue

                    operationQueue.qualityOfService = .userInteractive

                    let operations = ips.map {
                        let ip = $0
                        let o = PingOperation(host: ip)

                        o.completionBlock = { [weak self] in
                            guard let self else { return }

                            if o.reachable {
                                devices.append(NetworkDevice(name: ip, host: ip, type: ip == routerIP ? .router : .regular))
                            }

                            completedOperations += 1

                            DispatchQueue.main.async {
                                self.delegate?.networkScannerDidUpdateProgress(currentIndex: completedOperations, totalCount: ips.count)
                            }
                        }

                        return o
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

    private func getIPAddress() -> String {
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

    private func getNetmask() -> String {
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

class NetworkUtility {
    func getGatewayInfo(completionHandler: @escaping (String) -> Void) {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if let endpoint = path.gateways.first {
                    switch endpoint {
                    case let .hostPort(host, _):
                        let remoteHost = host.debugDescription
                        print("Gateway: \(remoteHost)")
                        // Use callback here to return the ip address to the caller
                        completionHandler(remoteHost)
                    default:
                        break
                    }
                }
            }
        }

        monitor.start(queue: .global())
    }
}
