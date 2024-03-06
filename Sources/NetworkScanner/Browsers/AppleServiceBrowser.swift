//
//  AppleServiceBrowser.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 05.03.2024.
//

import Foundation
import Network

class AppleServiceBrowser {
    private let type: String = "_apple-mobdev2._tcp."

    private var browser: NWBrowser?

    var deviceDiscovered: ((Device) -> Void)?

    private let parameters: NWParameters = {
        let parameters = NWParameters.udp
        if let isOption = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            isOption.version = .v4
        }
        parameters.preferNoProxies = true
        return parameters
    }()

    func search() {
        let parameters = NWParameters()
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = true
        parameters.allowFastOpen = true

        stop()

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: parameters)
        self.browser = browser

        browser.stateUpdateHandler = { newState in
            if newState == .ready {}
        }

        browser.browseResultsChangedHandler = { _, changes in
            browser.cancel()

            for change in changes {
                if case let .added(added) = change {
                    if case let .service(name, type, domain, _) = added.endpoint {
                        let netConnection = NWConnection(to: added.endpoint, using: self.parameters)

                        netConnection.stateUpdateHandler = { newState in
                            switch newState {
                            case .ready:
                                guard let currentPath = netConnection.currentPath else { return }

                                if let endpoint = currentPath.remoteEndpoint {
                                    switch endpoint {
                                    case .hostPort(host: let host, port: _):
                                        switch host {
                                        case .ipv4:
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

                                                        let device = Device(name: hostName, host: hostAddress, macAddress: macAddress, model: nil)

                                                        self.deviceDiscovered?(device)
                                                    case let .failure(error):
                                                        print("Service did not resolve, error: \(error)")
                                                    }
                                                }
                                            }
                                        @unknown default:
                                            break
                                        }
                                    @unknown default:
                                        break
                                    }
                                }

                                netConnection.cancel()
                            @unknown default:
                                break
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
        browser?.cancel()
        browser = nil
    }
}
