//
//  AirPlayServiceBrowser.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 06.03.2024.
//

import Foundation
import Network

class AirPlayServiceBrowser {
    private let type: String = "_airplay._tcp."

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
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: parameters)
        self.browser = browser

        browser.stateUpdateHandler = { newState in
            if newState == .ready {}
        }

        browser.browseResultsChangedHandler = { _, changes in
            browser.cancel()

            for change in changes {
                if case let .added(added) = change {
                    if case let .service(name, _, _, _) = added.endpoint {
                        let netConnection = NWConnection(to: added.endpoint, using: self.parameters)

                        netConnection.stateUpdateHandler = { newState in
                            switch newState {
                            case .ready:
                                guard let currentPath = netConnection.currentPath else { return }

                                if let endpoint = currentPath.remoteEndpoint {
                                    switch endpoint {
                                    case let .hostPort(host: host, port: _):
                                        switch host {
                                        case .ipv4:
                                            let macAddress = added.metadata.info["deviceid"]
                                            let model = added.metadata.info["model"]

                                            let device = Device(name: name, host: host.debugDescription.components(separatedBy: "%").first ?? host.debugDescription, macAddress: macAddress, model: model)

                                            self.deviceDiscovered?(device)
                                        @unknown default:
                                            break
                                        }
                                    @unknown default:
                                        break
                                    }
                                }
                            @unknown default:
                                break
                            }
                        }

                        netConnection.start(queue: .main)
                    }
                }
            }
        }

        browser.start(queue: DispatchQueue.main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}
