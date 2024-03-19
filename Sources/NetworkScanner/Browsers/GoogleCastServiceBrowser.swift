//
//  GoogleCastServiceBrowser.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 06.03.2024.
//

import Foundation
import Network

class GoogleCastServiceBrowser {
    private let type: String = "_googlecast._tcp"

    private var browser: NWBrowser?

    var deviceDiscovered: ((NetworkDevice) -> Void)?

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
                    if case let .service(name, _, _, _) = added.endpoint {
                        let netConnection = NWConnection(to: added.endpoint, using: self.connectionParameters)

                        netConnection.stateUpdateHandler = { newState in
                            if case .ready = newState {
                                guard let currentPath = netConnection.currentPath else { return }

                                if let endpoint = currentPath.remoteEndpoint {
                                    if case let .hostPort(host: host, port: _) = endpoint {
                                        if case .ipv4 = host {
                                            let normalName = added.metadata.info["fn"]
                                            let model = added.metadata.info["md"]

                                            let device = NetworkDevice(name: normalName ?? name, host: host.debugDescription.components(separatedBy: "%").first ?? host.debugDescription, macAddress: nil, model: model)

                                            self.deviceDiscovered?(device)
                                        }
                                    }
                                }

                                netConnection.cancel()
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
        if browser?.state != .cancelled {
            browser?.cancel()
        }
        browser = nil
    }
}
