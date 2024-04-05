//
//  PingOperation.swift
//
//  Copyright (c) 2024 Light Apps Studio
//  Created on 05.04.2024.
//

import Foundation
import NetworkScannerInternal

class PingOperation: Operation {
    private let lockQueue = DispatchQueue(label: "NetworkScannerPingOperation", attributes: .concurrent)

    let host: String

    private var pinger: GBPing?
    private var timeout: Int = 0
    private var failedToSendPing: Int = 0

    var isReachable: Bool = false

    init(host: String) {
        self.host = host
        super.init()
    }

    override var isAsynchronous: Bool {
        true
    }

    private var _isExecuting: Bool = false
    override private(set) var isExecuting: Bool {
        get {
            lockQueue.sync { () -> Bool in
                _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _isFinished: Bool = false
    override private(set) var isFinished: Bool {
        get {
            lockQueue.sync { () -> Bool in
                _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }

    override func start() {
        isFinished = false
        isExecuting = true
        main()
    }

    override func main() {
        let ping = GBPing()

        pinger = ping

        ping.host = host
        ping.delegate = self
        ping.timeout = 4.0
        ping.pingPeriod = 1.0

        ping.setup { success, _ in
            if success {
                ping.startPinging()
            } else {
                self.finish()
            }
        }
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }
}

extension PingOperation: GBPingDelegate {
    func ping(_ pinger: GBPing, didReceiveReplyWith summary: GBPingSummary) {
//        print("REPLY>\t\(summary)")

        isReachable = true

        pinger.stop()
        finish()
    }

    func ping(_ pinger: GBPing, didReceiveUnexpectedReplyWith summary: GBPingSummary) {
//        print("BREPLY>\t\(summary)")
    }

    func ping(_ pinger: GBPing, didSendPingWith summary: GBPingSummary) {
//        print("SENT>\t\(summary)")
    }

    func ping(_ pinger: GBPing, didTimeoutWith summary: GBPingSummary) {
//        print("TIMEOUT>\t\(summary)")
        timeout += 1

        if timeout > 2 {
            pinger.stop()
            finish()
        }
    }

    func ping(_ pinger: GBPing, didFailWithError error: Error) {
//        print("FAIL>\t\(error)")

        pinger.stop()
        finish()
    }

    func ping(_ pinger: GBPing, didFailToSendPingWith summary: GBPingSummary, error: Error) {
//        print("FSENT>\t\(summary), \(error)")

//        if let nsError = error as NSError? {
//            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 64 {
//                pinger.stop()
//                self.finish()
//            }
//        }

        failedToSendPing += 1

        if failedToSendPing > 10 {
            pinger.stop()
            finish()
        }
    }
}
