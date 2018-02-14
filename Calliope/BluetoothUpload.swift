import Foundation
import CoreBluetooth
import iOSDFULibrary

enum BluetoothUploadState {
    case ready
    case retrieving(uuid:UUID)
    case missing(uuid:UUID)
    case rebooted(peripheral: CBPeripheral)
    case uploading(progress:Float)
    case success
    case error(Error)
}

typealias UploadBlock = (BluetoothUploadState) -> Void

final class BluetoothUpload: NSObject, LoggerDelegate, DFUServiceDelegate, DFUProgressDelegate {

    private let bin: Data
    private let dat: Data
    private let uuid: UUID
    private let block: UploadBlock

    private var rebooting: BluetoothReboot?
    private var uploading: DFUServiceController?

    init(bin: Data, dat: Data, uuid: UUID, _ uploadBlock: @escaping UploadBlock) {
        self.bin = bin
        self.dat = dat
        self.uuid = uuid
        self.block = uploadBlock
        uploadBlock(.ready)
    }

    func start() {
        guard rebooting == nil else { return }
        guard uploading == nil else { return }

        guard let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application) else {
            block(.error("failed to create firmware"))
            return
        }

        unowned let me = self

        block(.retrieving(uuid: uuid))

        rebooting = BluetoothReboot(identifier: uuid, { error, central, peripheral in
            if let error = error {
                me.block(.error(error))
                return
            }

            if let peripheral = peripheral {

                LOG("uploader found peripheral \(peripheral.identifier)")

                me.block(.rebooted(peripheral: peripheral))

                let initiator = DFUServiceInitiator(centralManager: central, target: peripheral).with(firmware: firmware)
                initiator.logger = me
                initiator.delegate = me
                initiator.progressDelegate = me
                me.uploading = initiator.start()
            } else {

                ERR("uploader failed ot find peripheral \(me.uuid)")

                me.block(.missing(uuid:me.uuid))
            }
        })
    }

    func stop() {
        guard rebooting != nil else { return }
        if let controller = uploading {
            _ = controller.abort()
        }

        rebooting = nil
        uploading = nil

        block(.ready)
    }


    func logWith(_ level: LogLevel, message: String) {
        LOG(message)
    }

    func dfuStateDidChange(to state: DFUState) {
        LOG("state: \(state.description)")
        switch(state) {
        case .aborted:
            break
        case .completed:
            block(.success)
            break
        case .connecting:
            break
        case .disconnecting:
            break
        case .enablingDfuMode:
            break
        case .starting:
            block(.uploading(progress:0.0))
            break
        case .uploading:
            break
        case .validating:
            break
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        block(.error(message))
        rebooting = nil
        uploading = nil
    }

    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        // print("\(part)/\(totalParts) \(progress)")
        block(.uploading(progress:Float(progress)/100.0))
    }

    deinit {
        print("upload deinit")
    }

}
