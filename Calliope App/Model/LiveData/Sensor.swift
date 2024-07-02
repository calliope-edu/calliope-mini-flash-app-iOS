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

let rgbLed = Sensor(calliopeService: .rgbLed, name: "RGB Led", numOfAxis: 1)

let microphone = Sensor(calliopeService: .microphone, name: "microphone", numOfAxis: 1)

let speaker = Sensor(calliopeService: .speaker, name: "Lautsprecher", numOfAxis: 1)

let brightness = Sensor(calliopeService: .brightness, name: "Helligkeit", numOfAxis: 1)

let touchPin = Sensor(calliopeService: .touchPin, name: "Touch Pin", numOfAxis: 1)

let gesture = Sensor(calliopeService: .gesture, name: "Gesture", numOfAxis: 1)

let accelerometer = Sensor(calliopeService: .accelerometer, name: "Accelerometer", numOfAxis: 3)

let magnetometer = Sensor(calliopeService: .magnetometer, name: "Magetometer", numOfAxis: 1)
    
let button = Sensor(calliopeService: .button, name: "Button", numOfAxis: 1)

let ioPin = Sensor(calliopeService: .ioPin, name: "io Pin", numOfAxis: 1)

//let led = Sensor(calliopeService: .led, name: "LED")

let event = Sensor(calliopeService: .event, name: "Event", numOfAxis: 1)

let temperature = Sensor(calliopeService: .temperature, name: "Temperature", numOfAxis: 1)
    
let uart = Sensor(calliopeService: .uart, name: "Brightness (Uart)", numOfAxis: 1)

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
