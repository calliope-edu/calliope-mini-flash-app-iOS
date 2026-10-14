//
//  FlashService.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation

final class FlashService {

    private let connection: DeviceConnectionService
    // The calliopes hold their DFU delegates weakly, so the running job has to be retained here.
    private var activeJob: FlashJob?

    init(connection: DeviceConnectionService) {
        self.connection = connection
    }

    @discardableResult
    func flash(_ hex: Hex, events: @escaping (UploadEvent) -> Void) -> FlashJob? {
        guard let target = connection.currentCalliope else {
            LogNotify.error("No calliope connected. Canceling upload.")
            events(.failed(.notConnected))
            return nil
        }

        let fileHexTypes = hex.getHexTypes()
        LogNotify.log("[FlashService] File hex types: \(fileHexTypes), compatible: \(target.compatibleHexTypes)")
        guard target.compatibleHexTypes.contains(where: fileHexTypes.contains) else {
            LogNotify.log("[FlashService] ERROR: Hex version mismatch!")
            events(.failed(.incompatibleHex))
            return nil
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
        return job
    }
}
