import Foundation
import CoreBluetooth

final class BluetoothDiscovery {

    public let peripheral: CBPeripheral
    public let advertisementData: [String : Any]
    public let rssi: NSNumber

    init(peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = rssi
    }

    var name: String? {
        get {
            if let localName = advertisementData["kCBAdvDataLocalName"] as? String {
                return localName
            }
            return peripheral.name
        }
    }
}

typealias ScanBlock = ([UUID : BluetoothDiscovery]) -> Void

final class BluetoothScan: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    private let central: CBCentralManager
    private let scannerBlock: ScanBlock
    private var discoveriesMap: [UUID : BluetoothDiscovery] = [:]
    private var shouldBeRunning = false

    init(_ scannerBlock: @escaping ScanBlock) {
        self.central = CBCentralManager()
        self.scannerBlock = scannerBlock
        super.init()
        self.central.delegate = self
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if shouldBeRunning {
                start()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        discoveriesMap[peripheral.identifier] = BluetoothDiscovery(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI)

        scannerBlock(discoveriesMap)
    }

    func start() {
        shouldBeRunning = true

        guard central.state == .poweredOn else { return }
        guard central.isScanning == false else { return }

        LOG("scan start")

        // FIXME scan for specific services
        // https://github.com/calliope-mini/microbit-dal/blob/master/source/bluetooth/MicroBitBLEManager.cpp#L424
        central.scanForPeripherals(withServices: nil, options: [:])

//        central.scanForPeripherals(withServices: [
//            CBUUID(string:"A8A9DF22-19FA-62A0-0A47-1D25B0935DE9")
//        ] , options: [:])

    }

    func stop() {
        shouldBeRunning = false

        guard central.state == .poweredOn else { return }
        guard central.isScanning == true else { return }

        central.stopScan()
        LOG("scan stop")
    }

    deinit {
        print("scan deinit")
    }
}
