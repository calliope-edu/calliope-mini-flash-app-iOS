//
//  SensorUtility.swift
//  Calliope App
//
//  Created by itestra on 27.05.24.
//  Copyright © 2024 calliope. All rights reserved.
//

import Foundation

let rgbLed = Sensor(calliopeService: .rgbLed, name: "RGB Led")

let microphone = Sensor(calliopeService: .microphone, name: "microphone")

let speaker = Sensor(calliopeService: .speaker, name: "Lautsprecher")

let brightness = Sensor(calliopeService: .brightness, name: "Helligkeit")

let touchPin = Sensor(calliopeService: .touchPin, name: "Touch Pin")

let gesture = Sensor(calliopeService: .gesture, name: "Gesture")

let accelerometer = Sensor(calliopeService: .accelerometer, name: "Accelerometer")

let magnetometer = Sensor(calliopeService: .magnetometer, name: "Magetometer")
    
let button = Sensor(calliopeService: .button, name: "Button")

let ioPin = Sensor(calliopeService: .ioPin, name: "io Pin")

//let led = Sensor(calliopeService: .led, name: "LED")

let event = Sensor(calliopeService: .event, name: "Event")

let temperature = Sensor(calliopeService: .temperature, name: "Temperature")
    
let uart = Sensor(calliopeService: .uart, name: "Brightness (Uart)")

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
