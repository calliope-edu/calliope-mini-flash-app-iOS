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

final class BluetoothUpload: NSObject, LoggerDelegate, DFUServiceDelegate, DFUProgressDelegate {

    private let bin: Data
    private let dat: Data
    private let uuid: UUID
    private let uploadCallback: (BluetoothUploadState) -> Void

    private var rebooting: BluetoothReboot?
    private var uploading: DFUServiceController?

    init(bin: Data, dat: Data, uuid: UUID, _ uploadCallback: @escaping (BluetoothUploadState) -> Void) {
        self.bin = bin
        self.dat = dat
        self.uuid = uuid
        self.uploadCallback = uploadCallback
        uploadCallback(.ready)
    }

    func start() {
        guard rebooting == nil else { return }
        guard uploading == nil else { return }

        guard let firmware = DFUFirmware(binFile:bin, datFile:dat, type: .application) else {
            uploadCallback(.error("failed to create firmware"))
            return
        }

        uploadCallback(.retrieving(uuid: uuid))

		rebooting = BluetoothReboot(identifier: uuid, { [weak self] error, central, peripheral in

			guard let me = self else { return }

			if let error = error {
				me.uploadCallback(.error(error))
                return
            }

            if let peripheral = peripheral {

                LOG("uploader found peripheral \(peripheral.identifier)")

				me.uploadCallback(.rebooted(peripheral: peripheral))

                let initiator = DFUServiceInitiator().with(firmware: firmware)
                initiator.logger = me
                initiator.delegate = me
                initiator.progressDelegate = me
                me.uploading = initiator.start(target: peripheral)
            } else {

                ERR("uploader failed to find peripheral \(me.uuid)")

                me.uploadCallback(.missing(uuid:me.uuid))
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

        uploadCallback(.ready)
    }


    func logWith(_ level: LogLevel, message: String) {
        LOG(message)
    }

    func dfuStateDidChange(to state: DFUState) {
		LOG("state: \(String(describing: state.description))")
        switch(state) {
        case .aborted:
            break
        case .completed:
            uploadCallback(.success)
            break
        case .connecting:
            break
        case .disconnecting:
            break
        case .enablingDfuMode:
            break
        case .starting:
            uploadCallback(.uploading(progress:0.0))
            break
        case .uploading:
            break
        case .validating:
            break
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        uploadCallback(.error(message))
        rebooting = nil
        uploading = nil
    }

    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        // print("\(part)/\(totalParts) \(progress)")
        uploadCallback(.uploading(progress:Float(progress)/100.0))
    }

    deinit {
        print("upload deinit")
    }

}
