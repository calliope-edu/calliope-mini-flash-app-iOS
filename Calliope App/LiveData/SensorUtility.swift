//
//  SensorUtility.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

let rgbLed = Sensor(calliopeService: .rgbLed)

let microphone = Sensor(calliopeService: .microphone)

let speaker = Sensor(calliopeService: .speaker)

let brightness = Sensor(calliopeService: .brightness)

let touchPin = Sensor(calliopeService: .touchPin)

let gesture = Sensor(calliopeService: .gesture)

let accelerometer = Sensor(calliopeService: .accelerometer)

let magnetometer = Sensor(calliopeService: .magnetometer)
    
let button = Sensor(calliopeService: .button)

let ioPin = Sensor(calliopeService: .ioPin)

let led = Sensor(calliopeService: .led)

let event = Sensor(calliopeService: .event)

let temperature = Sensor(calliopeService: .temperature)
    
let uart = Sensor(calliopeService: .uart)

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
        .led: led,
        .event: event,
        .temperature: temperature,
        .uart: uart,
    ]

}
