//
//  FlashService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Combine
import Foundation

final class FlashService {

    private let connection: DeviceConnectionService
    // The calliopes hold their DFU delegates weakly, so the running job has to be retained here.
    private var activeJob: FlashJob?
    private var connectionLostSubscription: AnyCancellable?

    init(connection: DeviceConnectionService) {
        self.connection = connection
        // A gone peripheral never reaches the DFU library's finished/failed callback.
        connectionLostSubscription = connection.connectionLost.sink { [weak self] in
            self?.activeJob?.connectionLost()
        }
    }

    func flash(_ hex: Hex, events: @escaping (UploadEvent) -> Void) {
        guard let target = connection.currentCalliope else {
            LogNotify.error("No calliope connected. Canceling upload.")
            events(.failed(.notConnected))
            return
        }

        let fileHexTypes = hex.getHexTypes()
        LogNotify.log("[FlashService] File hex types: \(fileHexTypes), compatible: \(target.compatibleHexTypes)")
        guard target.compatibleHexTypes.contains(where: fileHexTypes.contains) else {
            LogNotify.log("[FlashService] ERROR: Hex version mismatch!")
            events(.failed(.incompatibleHex))
            return
        }

        activeJob?.abandon()
        let job = FlashJob(hex: hex, target: target, connection: connection, events: events)
        job.onEnd = { [weak self, weak job] in
            if let self, self.activeJob === job {
                self.activeJob = nil
            }
        }
        activeJob = job
        job.start()
    }

    func cancel() {
        activeJob?.cancel()
    }
}
