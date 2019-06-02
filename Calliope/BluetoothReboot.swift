import Foundation
import CoreBluetooth

typealias RebootBlock = (Error?, CBCentralManager, CBPeripheral?) -> Void

fileprivate enum BluetoothRebootState {
    case disconnected
    case connected
    case wrote
}

final class BluetoothReboot: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    private let identifier: UUID
    private let central: CBCentralManager
    private var peripheral: CBPeripheral? = nil
    private var state: BluetoothRebootState = .disconnected

    private let block: RebootBlock

    init(identifier: UUID, _ rebootBlock: @escaping RebootBlock) {
        self.identifier = identifier
        self.central = CBCentralManager()
        self.block = rebootBlock
        super.init()
        self.central.delegate = self
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //print("manager: didUpdateState \(central.state.text)")
        switch(central.state) {
        case .poweredOn:
            if let peripheral = central.retrievePeripherals(withIdentifiers: [identifier]).first {
                LOG("peripheral: found \(identifier)")

                self.peripheral = peripheral
                peripheral.delegate = self
                LOG("peripheral: connecting")
                central.connect(peripheral, options: [:])

            } else {
                LOG("peripheral: faild to find \(identifier)")
                block("faild to find peripheral \(identifier)", central, nil)
            }
        case .poweredOff:
            block("bluetooth turned off", central, nil)
        case .resetting:
            block("bluetooth resetting", central, nil)
        case .unauthorized:
            block("bluetooth unauthorized", central, nil)
        case .unsupported:
            block("bluetooth unsupported", central, nil)
		default:
            block("bluetooth state unknown", central, nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        LOG("peripheral: connected \(identifier.uuidString)")
        //print("peripheral: discoverServices \(identifier.uuidString)")
        state = .connected
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        LOG("peripheral: failed to connect to \(identifier.uuidString)")
        block("failed to connect to peripheral \(identifier.uuidString)", central, nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        LOG("peripheral: disconnected from peripheral \(identifier.uuidString): \(error.debugDescription)")

        if state == .wrote {
            block(nil, central, peripheral)
        } else {
            block("premature disconnected", central, peripheral)
        }

        state = .disconnected
        self.peripheral = nil
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        //print("peripheral: name=\(peripheral.name ?? "")")
    }

    func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        //print("peripheral: peripheralDidUpdateRSSI")
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        //print("peripheral: didReadRSSI")
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        //print("peripheral: didModifyServices")
        //if let services = peripheral.services {
        //    for service in services {
        //        print("peripheral: didModifyServices \(service.uuid.uuidString)")
        //    }
        //}
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        LOG("peripheral: didDiscoverServices \(peripheral.identifier.uuidString) [\(peripheral.services?.count ?? 0)]")
        //if let services = peripheral.services {
        //    for service in services {
        //        print("peripheral: didDiscoverServices - \(service.uuid.uuidString)")
        //    }
        //}

        //print("peripheral: discoverIncludedServices")
        //if let services = peripheral.services {
        //    for service in services {
        //        peripheral.discoverIncludedServices([], for: service)
        //    }
        //}

        LOG("peripheral: discoverCharacteristics")
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics([], for: service)
            }
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        LOG("service: didDiscoverIncludedServicesFor \(service.uuid.uuidString) [\(service.includedServices?.count ?? 0)]")
        //if let includedServices = service.includedServices {
        //    for includedService in includedServices {
        //        print("service: didDiscoverIncludedServicesFor - \(includedService.uuid.uuidString)")
        //    }
        //}
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        LOG("service: didDiscoverCharacteristicsFor \(service.uuid.uuidString) [\(service.characteristics?.count ?? 0)]")
        //if let characteristics = service.characteristics {
        //    for characteristic in characteristics {
        //        print("service: didDiscoverCharacteristicsFor - \(characteristic.uuid.uuidString)")
        //        print(" broadcast: \(characteristic.properties.contains(.broadcast))")
        //        print(" read: \(characteristic.properties.contains(.read))")
        //        print(" write: \(characteristic.properties.contains(.write))")
        //        print(" writeWithoutResponse: \(characteristic.properties.contains(.writeWithoutResponse))")
        //        print(" notify: \(characteristic.properties.contains(.notify))")
        //        print(" indicate: \(characteristic.properties.contains(.indicate))")
        //        print(" authenticatedSignedWrites: \(characteristic.properties.contains(.authenticatedSignedWrites))")
        //        print(" notifyEncryptionRequired: \(characteristic.properties.contains(.notifyEncryptionRequired))")
        //        print(" indicateEncryptionRequired: \(characteristic.properties.contains(.indicateEncryptionRequired))")
        //        print(" extendedProperties: \(characteristic.properties.contains(.extendedProperties))")
        //    }
        //}

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.readValue(for: characteristic)
            }
        }


        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if (characteristic.uuid == uuid_service_reboot) {
                    LOG("writing reboot to dfu")
                    let data = Data(bytes: [0x01])
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                    state = .wrote
                }
            }
        }

    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("characteristic: didUpdateValueFor \(characteristic)")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        LOG("characteristic: didWriteValueFor")
        state = .wrote
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        //print("characteristic: didUpdateNotificationStateFor")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        //print("characteristic: didDiscoverDescriptorsFor")
    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        //print("descriptor: didUpdateValueFor \(descriptor.uuid.uuidString)")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        //print("descriptor: didWriteValueFor \(descriptor.uuid.uuidString)")
    }

    deinit {
        print("reboot deinit")
    }

}
