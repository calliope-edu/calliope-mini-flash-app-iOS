import CoreBluetooth

// FIXME
let uuid_peripheral_calliope = UUID(uuidString: "19D1B789-0D1A-4103-8E2E-80C981934FF1")!

let uuid_service_reboot = CBUUID(string:"E95D93B1-251D-470A-A062-FA1922DFA9A8")
let uuid_service_dfu = CBUUID(string:"E95D93B0-251D-470A-A062-FA1922DFA9A8")
let uuid_service_info = CBUUID(string:"180A")
let uuid_characteristic_dfu_control = CBUUID(string:"E95D93B1-251D-470A-A062-FA1922DFA9A8")

let uuid_characteristic_info_firmware = CBUUID(string:"2A24")

// https://lancaster-university.github.io/microbit-docs/resources/bluetooth/bluetooth_profile.html
// https://github.com/tamaki-shingo/Microbit.swift/blob/master/Microbit.swft
// https://www.spinics.net/lists/linux-bluetooth/msg69231.html
// https://github.com/lancaster-university/microbit-dal/blob/master/source/bluetooth/MicroBitDFUService.cpp
