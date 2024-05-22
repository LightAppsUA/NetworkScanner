//
//  LocalNetworkAuthorization.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation
import Network
import os

public class LocalNetworkAuthorization: NSObject {
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?

    private let logger = Logger()

    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion

        // Create parameters, and allow browsing over peer-to-peer link.
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Browse for a custom service type.
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { newState in
            switch newState {
            case let .failed(error):
                self.logger.error("NWBrowser error: \(error.localizedDescription)")
            case .ready, .cancelled:
                break
            case let .waiting(error):
                self.logger.warning("Local network permission has been denied: \(error)")
                self.reset()
                self.completion?(false)
            default:
                break
            }
        }

        netService = NetService(domain: "local.", type: "_lnp._tcp.", name: "LocalNetworkPrivacy", port: 1100)
        netService?.delegate = self

        self.browser?.start(queue: .main)
        netService?.publish()
    }

    private func reset() {
        browser?.cancel()
        browser = nil
        netService?.stop()
        netService = nil
    }
}

extension LocalNetworkAuthorization: NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        reset()
        logger.info("Local network permission has been granted")
        completion?(true)
    }
}
