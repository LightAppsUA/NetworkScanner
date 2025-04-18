//
//  BonjourResolver.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation
import Network

final class BonjourResolver: NSObject, NetServiceDelegate {
    typealias CompletionHandler = (Result<(String, Int), Error>) -> Void

    @discardableResult
    static func resolve(service: NetService, completionHandler: @escaping CompletionHandler) -> BonjourResolver {
        precondition(Thread.isMainThread)
        let resolver = BonjourResolver(service: service, completionHandler: completionHandler)
        resolver.start()
        return resolver
    }

    private init(service: NetService, completionHandler: @escaping CompletionHandler) {
        // We want our own copy of the service because we’re going to set a
        // delegate on it but `NetService` does not conform to `NSCopying` so
        // instead we create a copy by copying each property.
        let copy = NetService(domain: service.domain, type: service.type, name: service.name)
        self.service = copy
        self.completionHandler = completionHandler
    }

    deinit {
        // If these fire the last reference to us was released while the resolve
        // was still in flight.  That should never happen because we retain
        // ourselves on `start`.
        assert(self.service == nil)
        assert(self.completionHandler == nil)
        assert(self.selfRetain == nil)
    }

    private var service: NetService? = nil
    private var completionHandler: CompletionHandler? = nil
    private var selfRetain: BonjourResolver? = nil

    private func start() {
        precondition(Thread.isMainThread)
        guard let service else { fatalError() }
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Form a temporary retain loop to prevent us from being deinitialised
        // while the resolve is in flight.  We break this loop in `stop(with:)`.
        selfRetain = self
    }

    func stop() {
        stop(with: .failure(CocoaError(.userCancelled)))
    }

    private func stop(with result: Result<(String, Int), Error>) {
        precondition(Thread.isMainThread)
        service?.delegate = nil
        service?.stop()
        service = nil
        let completionHandler = completionHandler
        self.completionHandler = nil
        completionHandler?(result)

        selfRetain = nil
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let hostName = sender.hostName!
        let port = sender.port
        stop(with: .success((hostName, port)))
    }

    func netService(_: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let code = (errorDict[NetService.errorCode]?.intValue)
            .flatMap { NetService.ErrorCode(rawValue: $0) }
            ?? .unknownError
        let error = NSError(domain: NetService.errorDomain, code: code.rawValue, userInfo: nil)
        stop(with: .failure(error))
    }
}
