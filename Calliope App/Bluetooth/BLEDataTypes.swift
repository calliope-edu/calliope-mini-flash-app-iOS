//
//  BluetoothTypes.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 23.02.19.
//

import Foundation

struct BLEDataTypes {
	enum PinConfiguration {
		case Digital
		case Analogue
	}

	enum ButtonPressAction: UInt8 {
		case Up = 0
		case Down = 1
		case Long = 2
	}

	enum AccelerometerGesture: UInt8 {
		case tiltUp = 1
		case tiltDown = 2
		case tiltLeft = 3
		case tiltRight = 4
		
		case faceUp = 5
		case faceDown = 6

		case freefall = 7

		case acceleration3g = 8
		case acceleration6g = 9
		case acceleration8g = 10

		case shake = 11
	}

	//Identifiers used in the firmware for sending via event message bus
	enum EventSource: UInt16 {

		case ANY                             = 0

		case MICROBIT_ID_BUTTON_A            = 1
		case MICROBIT_ID_BUTTON_B            = 2
		case MICROBIT_ID_BUTTON_RESET        = 3
		case MICROBIT_ID_ACCELEROMETER       = 4
		case MICROBIT_ID_COMPASS             = 5
		case MICROBIT_ID_DISPLAY             = 6

		case MICROBIT_ID_IO_P0               = 7
		case MICROBIT_ID_IO_P1               = 8
		case MICROBIT_ID_IO_P2               = 9
		case MICROBIT_ID_IO_P3               = 10
		case MICROBIT_ID_IO_P4               = 11
		case MICROBIT_ID_IO_P5               = 12
		case MICROBIT_ID_IO_P6               = 13
		case MICROBIT_ID_IO_P7               = 14
		case MICROBIT_ID_IO_P8               = 15
		case MICROBIT_ID_IO_P9               = 16
		case MICROBIT_ID_IO_P10              = 17
		case MICROBIT_ID_IO_P11              = 18
		case MICROBIT_ID_IO_P12              = 19
		case MICROBIT_ID_IO_P13              = 20
		case MICROBIT_ID_IO_P14              = 21
		case MICROBIT_ID_IO_P15              = 22
		case MICROBIT_ID_IO_P16              = 23
		case MICROBIT_ID_IO_P19              = 24
		case MICROBIT_ID_IO_P20              = 25

		case MICROBIT_ID_IO_P21              = 50

		case MICROBIT_ID_BUTTON_AB           = 26
		case MICROBIT_ID_GESTURE             = 27
		case MICROBIT_ID_THERMOMETER         = 28
		case MICROBIT_ID_SERIAL              = 32
	}

	struct EventValue: ExpressibleByIntegerLiteral, Equatable {
		typealias IntegerLiteralType = UInt16.IntegerLiteralType

		init(integerLiteral value: UInt16.IntegerLiteralType) {
			self.init(value)
		}

		static let ANY = EventValue(0)
		var value: UInt16
		fileprivate init(_ value: UInt16) { self.value = value }
	}

	enum AccelerometerEventValue: EventValue {
		//case MICROBIT_ACCELEROMETER_EVT_NONE         = 0 // TODO: why this?
		case MICROBIT_ACCELEROMETER_EVT_TILT_UP      = 1
		case MICROBIT_ACCELEROMETER_EVT_TILT_DOWN    = 2
		case MICROBIT_ACCELEROMETER_EVT_TILT_LEFT    = 3
		case MICROBIT_ACCELEROMETER_EVT_TILT_RIGHT   = 4
		case MICROBIT_ACCELEROMETER_EVT_FACE_UP      = 5
		case MICROBIT_ACCELEROMETER_EVT_FACE_DOWN    = 6
		case MICROBIT_ACCELEROMETER_EVT_FREEFALL     = 7
		case MICROBIT_ACCELEROMETER_EVT_2G           = 8
		case MICROBIT_ACCELEROMETER_EVT_3G           = 9
		case MICROBIT_ACCELEROMETER_EVT_6G           = 10
		//case MICROBIT_ACCELEROMETER_EVT_8G           = 11 // TODO: in one declaration, this is not defined
		case MICROBIT_ACCELEROMETER_EVT_SHAKE        = 11 // TODO: in one declaration it´s 11, in the other 12
	}

	enum ButtonEvent: EventValue {
		case MICROBIT_BUTTON_EVT_DOWN                = 1
		case MICROBIT_BUTTON_EVT_UP                  = 2
		case MICROBIT_BUTTON_EVT_CLICK               = 3
		case MICROBIT_BUTTON_EVT_LONG_CLICK          = 4
		case MICROBIT_BUTTON_EVT_HOLD                = 5
		case MICROBIT_BUTTON_EVT_DOUBLE_CLICK        = 6
	}

	enum CompassEvent: EventValue {
		@available(*, deprecated)
		case MICROBIT_COMPASS_EVT_CAL_REQUIRED       = 1
		@available(*, deprecated)
		case MICROBIT_COMPASS_EVT_CAL_START          = 2
		@available(*, deprecated)
		case MICROBIT_COMPASS_EVT_CAL_END            = 3

		case MICROBIT_COMPASS_EVT_DATA_UPDATE        = 4
		case MICROBIT_COMPASS_EVT_CONFIG_NEEDED      = 5
		case MICROBIT_COMPASS_EVT_CALIBRATE          = 6
		case MICROBIT_COMPASS_EVT_CALIBRATION_NEEDED = 7
	}

	enum DisplayEvent: EventValue {
		case MICROBIT_DISPLAY_EVT_ANIMATION_COMPLETE = 1
		case MICROBIT_DISPLAY_EVT_LIGHT_SENSE        = 2
	}

	typealias TouchPinEvent = ButtonEvent

	enum IOPinEvent: EventValue {
		case MICROBIT_PIN_EVT_RISE                   = 2
		case MICROBIT_PIN_EVT_FALL                   = 3
		case MICROBIT_PIN_EVT_PULSE_HI               = 4
		case MICROBIT_PIN_EVT_PULSE_LO               = 5
	}

	enum SerialEvent: EventValue {
		case MICROBIT_SERIAL_EVT_DELIM_MATCH         = 1
		case MICROBIT_SERIAL_EVT_HEAD_MATCH          = 2
		case MICROBIT_SERIAL_EVT_RX_FULL             = 3
	}

	enum ThermometerEvent: EventValue {
		case MICROBIT_THERMOMETER_EVT_UPDATE         = 1
	}
}
