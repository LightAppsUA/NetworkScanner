//
//  AppleServiceBrowser.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation
import Network
import os

class AppleServiceBrowser {
    private let type: String = "_apple-mobdev2._tcp"

    private var browser: NWBrowser?

    var deviceDiscovered: ((NetworkDevice) -> Void)?

    private let logger = Logger()

    private let connectionParameters: NWParameters = {
        let parameters = NWParameters.udp
        if let isOption = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            isOption.version = .v4
        }
        parameters.preferNoProxies = true
        return parameters
    }()

    private let browserParameters: NWParameters = {
        let parameters = NWParameters()
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = true
        parameters.allowFastOpen = true
        return parameters
    }()

    func search() {
        stop()

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: browserParameters)
        self.browser = browser

        browser.stateUpdateHandler = { newState in
            if newState == .ready {}
        }

        browser.browseResultsChangedHandler = { _, changes in
            if browser.state != .cancelled {
                browser.cancel()
            }

            for change in changes {
                if case let .added(added) = change {
                    if case let .service(name, type, domain, _) = added.endpoint {
                        let netConnection = NWConnection(to: added.endpoint, using: self.connectionParameters)

                        netConnection.stateUpdateHandler = { newState in
                            if case .ready = newState {
                                guard let currentPath = netConnection.currentPath else { return }

                                if let endpoint = currentPath.remoteEndpoint {
                                    if case .hostPort(host: let host, port: _) = endpoint {
                                        if case .ipv4 = host {
                                            DispatchQueue.main.async {
                                                let service = NetService(domain: domain, type: type, name: name)

                                                BonjourResolver.resolve(service: service) { result in
                                                    switch result {
                                                    case let .success(result):
                                                        let macAddress = name.components(separatedBy: "@").first?.uppercased()

                                                        var hostName = result.0
                                                        let postfix = ".local."

                                                        let hostAddress = host.debugDescription.components(separatedBy: "%").first ?? host.debugDescription

                                                        if result.0.hasSuffix(postfix) {
                                                            hostName = String(hostName.dropLast(postfix.count))
                                                        }

                                                        let device = NetworkDevice(name: hostName, host: hostAddress, macAddress: macAddress, model: nil)

                                                        self.deviceDiscovered?(device)
                                                    case let .failure(error):
                                                        self.logger.error("Service did not resolve, error: \(error)")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                netConnection.cancel()
                            }
                        }

                        netConnection.start(queue: .global())
                    }
                }
            }
        }

        browser.start(queue: .global())
    }

    func stop() {
        if browser?.state != .cancelled {
            browser?.cancel()
        }
        browser = nil
    }
}
