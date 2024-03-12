//
//  LocalNetworkAuthorization.swift
//  NetworkScanner
//
//  Created by Артем Твердохлєбов on 11.03.2024.
//

import Foundation
import Network

public class LocalNetworkAuthorization: NSObject {
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?

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
                print(error.localizedDescription)
            case .ready, .cancelled:
                break
            case let .waiting(error):
                print("Local network permission has been denied: \(error)")
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
        print("Local network permission has been granted")
        completion?(true)
    }
}
