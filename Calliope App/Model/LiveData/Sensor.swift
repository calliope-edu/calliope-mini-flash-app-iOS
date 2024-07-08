//
//  Sensor.swift
//  Calliope App
//
//  Created by itestra on 21.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation
import DGCharts

class Sensor {
    
    let calliopeService: CalliopeService
    let name: String
    let numOfAxis: Int
    
    
    init(calliopeService: CalliopeService, name: String, numOfAxis: Int) {
        self.calliopeService = calliopeService
        self.name = name
        self.numOfAxis = numOfAxis
    }
}

let rgbLed = Sensor(calliopeService: .rgbLed, name: NSLocalizedString("RGB Led", comment: ""), numOfAxis: 1)

let microphone = Sensor(calliopeService: .microphone, name: NSLocalizedString("Microphone", comment: ""), numOfAxis: 1)

let speaker = Sensor(calliopeService: .speaker, name: NSLocalizedString("Speaker", comment: ""), numOfAxis: 1)

let brightness = Sensor(calliopeService: .brightness, name: NSLocalizedString("Brightness", comment: ""), numOfAxis: 1)

let touchPin = Sensor(calliopeService: .touchPin, name: NSLocalizedString("Touch Pin", comment: ""), numOfAxis: 1)

let gesture = Sensor(calliopeService: .gesture, name: NSLocalizedString("Gesture", comment: ""), numOfAxis: 1)

let accelerometer = Sensor(calliopeService: .accelerometer, name: NSLocalizedString("Accelerometer", comment: ""), numOfAxis: 3)

let magnetometer = Sensor(calliopeService: .magnetometer, name: NSLocalizedString("Magnetometer", comment: ""), numOfAxis: 1)
    
let button = Sensor(calliopeService: .button, name: NSLocalizedString("Button", comment: ""), numOfAxis: 1)

let ioPin = Sensor(calliopeService: .ioPin, name: NSLocalizedString("IO Pin", comment: ""), numOfAxis: 1)

let event = Sensor(calliopeService: .event, name: NSLocalizedString("Event", comment: ""), numOfAxis: 1)

let temperature = Sensor(calliopeService: .temperature, name: NSLocalizedString("Temperature", comment: ""), numOfAxis: 1)
    
let uart = Sensor(calliopeService: .uart, name: NSLocalizedString("User defined (UART)", comment: ""), numOfAxis: 1)

struct SensorUtility {
    static let serviceSensorMap : [CalliopeService : Sensor] = [
        .rgbLed : rgbLed,
        .microphone : microphone,
        .speaker: speaker,
        .brightness : brightness,
        .touchPin : touchPin,
        .gesture : gesture,
        .accelerometer : accelerometer,
        .magnetometer : magnetometer,
        .button : button,
        .ioPin: ioPin,
        //.led: led,
        .event: event,
        .temperature: temperature,
        .uart: uart,
    ]

}
