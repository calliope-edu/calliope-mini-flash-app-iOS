//
//  CalliopeBLEProfile.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 23.02.19.
//

import CoreBluetooth

//Bluetooth profile of the Calliope

enum CalliopeService: String {

	//MARK: master service

	case master = "CA11FF01-251D-470A-A062-FA1922DFA9A8"

	//MARK: service for interpreter

	case interpreter = "FF44DDEE-251D-470A-A062-FA1922DFA9A8"

	//MARK: services for interpreter (legacy)

	case notify = "FF55DDEE-251D-470A-A062-FA1922DFA9A8"
	case program = "FF66DDEE-251D-470A-A062-FA1922DFA9A8"

	//MARK: custom calliope services

	case rgbLed = "CA110101-251D-470A-A062-FA1922DFA9A8"

	case microphone = "CA110201-251D-470A-A062-FA1922DFA9A8"

	case speaker = "CA110401-251D-470A-A062-FA1922DFA9A8"

	case brightness = "CA110301-251D-470A-A062-FA1922DFA9A8"

	case touchPin = "CA110501-251D-470A-A062-FA1922DFA9A8"

	case gesture = "CA110601-251D-470A-A062-FA1922DFA9A8"

	//MARK: services from BLE Profile of Microbit from Lancester University
	//https://lancaster-university.github.io/microbit-docs/resources/bluetooth/bluetooth_profile.html

	case accelerometer = "E95D0753251D470AA062FA1922DFA9A8"

	/// measures a magnetic field such as the earth's magnetic field in 3 axes.
	case magnetometer = "E95DF2D8251D470AA062FA1922DFA9A8"

	/// the two Micro Bit buttons, allows 'commands' associated with button state changes to be associated with button states and notified to a connected client.
	case button = "E95D9882251D470AA062FA1922DFA9A8"

	/// Provides read/write access to I/O pins, individually or collectively. Allows configuration of each pin for input/output and analogue/digital use.
	case ioPin = "E95D127B251D470AA062FA1922DFA9A8"

	/// Provides access to and control of LED state. Allows the state (ON or OFF) of all 25 LEDs to be set in a single write operation. Allows short text strings to be sent by a client for display on the LED matrix and scrolled across at a speed controlled by the Scrolling Delay characteristic.
	case led = "E95DD91D251D470AA062FA1922DFA9A8"

	/// A generic, bi-directional event communication service.
	/// The Event Service allows events or commands to be notified to the micro:bit by a connected client and it allows micro:bit to notify the connected client
	/// of events or commands originating from with the micro:bit. The micro:bit can inform the client of the types of event it is interested in being informed
	/// about (e.g. an incoming call) and the client can inform the micro:bit of types of event it wants to be notified about.
	/// The term “event” will be used here for both event and command types of data.
	/// Events may have an associated value.
	/// Note that specific event ID values including any special values such as those which may represent wild cards are not defined here.
	/// The micro:bit run time documentation should be consulted for this information.
	/// Multiple events of different types may be notified to the client or micro:bit at the same time.
	/// Event data is encoded as an array of structs each encoding an event of a given type together with an associated value.
	/// Event Type and Event Value are both defined as uint16 and therefore the length of this array will always be a multiple of 4.
	/// struct event {
	///    uint16 event_type;
	///    uint16 event_value;
	/// };
	case event = "E95D93AF251D470AA062FA1922DFA9A8"

	/// Ambient temperature derived from several internal temperature sensors on the micro:bit
	case temperature = "E95D6100251D470AA062FA1922DFA9A8"

	/// This is an implementation of Nordic Semicondutor's UART/Serial Port Emulation over Bluetooth low energy.
	/// See https://developer.nordicsemi.com/nRF5_SDK/nRF51_SDK_v8.x.x/doc/8.0.0/s110/html/a00072.html for the original Nordic Semiconductor documentation by way of background.
	case uart = "6E400001B5A3F393E0A9E50E24DCCA9E"
}



enum CalliopeCharacteristic: String, CaseIterable {

	//MARK: master service characteristic

	case services = "CA11FF02-251D-470A-A062-FA1922DFA9A8"

	//MARK: interpreter characteristics (current + legacy)
	case notify = "FF55DDEE-251D-470A-A062-FA1922DFA9A8"
	case program = "FF66DDEE-251D-470A-A062-FA1922DFA9A8"

	//MARK: custom calliope service characteristics

	case color = "CA110102-251D-470A-A062-FA1922DFA9A8"

	case noise = "CA110203-251D-470A-A062-FA1922DFA9A8"

	case playTone = "CA110402-251D-470A-A062-FA1922DFA9A8"

	case brightness = "CA110303-251D-470A-A062-FA1922DFA9A8"

	case touchPin = "CA110503-251D-470A-A062-FA1922DFA9A8"

	case gesture = "CA110603-251D-470A-A062-FA1922DFA9A8"

	//MARK: characteristics from microbit ble profile

	/// X, Y and Z axes as 3 signed 16 bit values in that order and in little endian format. X, Y and Z values should be divided by 1000.
	case accelerometerData = "E95DCA4B251D470AA062FA1922DFA9A8"
	/// frequency with which accelerometer data is reported in milliseconds. Valid values are 1, 2, 5, 10, 20, 80, 160 and 640.
	/// TODO: possible periods do not match with documentation
	case accelerometerPeriod = "E95DFB24251D470AA062FA1922DFA9A8"

	/// X, Y and Z axes as 3 signed 16 bit values in that order and in little endian format.
	case magnetometerData = "E95DFB11251D470AA062FA1922DFA9A8"
	//frequency with which magnetometer data is reported in milliseconds. Valid values are 1, 2, 5, 10, 20, 80, 160 and 640.
	/// TODO: possible periods do not match with documentation
	case magnetometerPeriod = "E95D386C251D470AA062FA1922DFA9A8"
	/// Compass bearing in degrees from North.
	case magnetometerBearing = "E95D9715251D470AA062FA1922DFA9A8"

	/// State of Button A may be read on demand by a connected client or the client may subscribe to notifications of state change. 3 button states are defined and represented by a simple numeric enumeration:  0 = not pressed, 1 = pressed, 2 = long press.
	case buttonAState = "E95DDA90251D470AA062FA1922DFA9A8"
	/// State of Button B may be read on demand by a connected client or the client may subscribe to notifications of state change. 3 button states are defined and represented by a simple numeric enumeration:  0 = not pressed, 1 = pressed, 2 = long press.
	case buttonBState = "E95DDA91251D470AA062FA1922DFA9A8"

	/// Contains data relating to zero or more pins. Structured as a variable length array of up to 19 Pin Number / Value pairs.
	/// Pin Number and Value are each uint8 fields.
	/// Note however that the micro:bit has a 10 bit ADC and so values are compressed to 8 bits with a loss of resolution.
	/// OPERATIONS:
	/// WRITE: Clients may write values to one or more pins in a single GATT write operation.
	/// A pin to which a value is to be written must have been configured for output using the Pin IO Configuration characteristic.
	/// Any attempt to write to a pin which is configured for input will be ignored.
	/// NOTIFY: Notifications will deliver Pin Number / Value pairs for those pins defined as input pins by the Pin IO Configuration characteristic
	/// and whose value when read differs from the last read of the pin.
	/// READ: A client reading this characteristic will receive Pin Number / Value pairs for all those pins defined as input pins by the Pin IO Configuration characteristic.*/
	case pinData = "E95D8D00251D470AA062FA1922DFA9A8"
	/// A bit mask which allows each pin to be configured for analogue or digital use. Bit n corresponds to pin n where 0 LESS THAN OR EQUAL TO n LESS THAN 19. A value of 0 means digital and 1 means analogue.
	/// TODO: documentation mismatch: documentation says uint24, but implementation seems to demand uint32
	case pinADConfiguration = "E95D5899251D470AA062FA1922DFA9A8"
	/// A bit mask (32 bit) which defines which inputs will be read. If the Pin AD Configuration bit mask is also set the pin will be read as an analogue input, if not it will be read as a digital input.
	/// Note that in practice, setting a pin's mask bit means that it will be read by the micro:bit runtime and, if notifications have been enabled on the Pin Data characteristic, data read will be transmitted to the connected Bluetooth peer device in a Pin Data notification. If the pin's bit is clear, it  simply means that it will not be read by the micro:bit runtime.
	/// Bit n corresponds to pin n where 0 LESS THAN OR EQUAL TO n LESS THAN 19. A value of 0 means configured for output and 1 means configured for input.
	/// TODO: documentation mismatch: documentation says uint24, but implementation seems to demand uint32
	case pinIOConfiguration = "E95DB9FE251D470AA062FA1922DFA9A8"
	/// A variable length array 1 to 2 instances of :
	/// struct PwmControlData
	/// {
	/// uint8_t     pin;
	/// uint16_t    value;
	/// uint32_t    period;
	/// }
	/// Period is in microseconds and is an unsigned int but transmitted.
	/// Value is in the range 0 – 1024, per the current DAL API (e.g. setAnalogValue). 0 means OFF.
	/// Fields are transmitted over the air in Little Endian format.
	case pwmControl = "E95DD822251D470AA062FA1922DFA9A8"

	/// Allows the state of any|all LEDs in the 5x5 grid to be set to on or off with a single GATT operation.
	/// Consists of an array of 5 x utf8 octets, each representing one row of 5 LEDs.
	/// Octet 0 represents the first row of LEDs i.e. the top row when the micro:bit is viewed with the edge connector at the bottom and USB connector at the top.
	/// Octet 1 represents the second row and so on.
	/// In each octet, bit 4 corresponds to the first LED in the row, bit 3 the second and so on.
	/// Bit values represent the state of the related LED: off (0) or on (1).
	/// So we have:
	/// Octet 0, LED Row 1: bit4 bit3 bit2 bit1 bit0
	/// Octet 1, LED Row 2: bit4 bit3 bit2 bit1 bit0
	/// Octet 2, LED Row 3: bit4 bit3 bit2 bit1 bit0
	/// Octet 3, LED Row 4: bit4 bit3 bit2 bit1 bit0
	/// Octet 4, LED Row 5: bit4 bit3 bit2 bit1 bit0
	case ledMatrixState = "E95D7B77251D470AA062FA1922DFA9A8"
	/// A short UTF-8 string to be shown on the LED display. Maximum length 20 octets.
	case ledText = "E95D93EE251D470AA062FA1922DFA9A8"
	/// Specifies a millisecond delay to wait for in between showing each character on the display.
	case scrollingDelay = "E95D0D2D251D470AA062FA1922DFA9A8"

	/// A variable length list of event data structures which indicates the types of client event, potentially with a specific value which the micro:bit wishes to be informed of when they occur. The client should read this characteristic when it first connects to the micro:bit. It may also subscribe to notifications to that it can be informed if the value of this characteristic is changed by the micro:bit firmware.
	/// struct event {
	/// 	uint16 event_type;
	/// 	uint16 event_value;
	/// };
	/// Note that an event_type of zero means ANY event type and an event_value part set to zero means ANY event value.
	/// event_type and event_value are each encoded in little endian format.
	case microBitRequirements = "E95DB84C251D470AA062FA1922DFA9A8"
	/// Contains one or more event structures which should be notified to the client. It supports notifications and as such the client should subscribe to notifications from this characteristic.
	/// struct event {
	/// 	uint16 event_type;
	/// 	uint16 event_value;
	/// };
	case microBitEvent = "E95D9775251D470AA062FA1922DFA9A8"
	/// a variable length list of event data structures which indicates the types of micro:bit event, potentially with a specific value which the client wishes to be informed of when they occur. The client should write to this characteristic when it first connects to the micro:bit.
	/// struct event {
	/// 	uint16 event_type;
	/// 	uint16 event_value;
	/// };
	/// Note that an event_type of zero means ANY event type and an event_value part set to zero means ANY event value.
	/// event_type and event_value are each encoded in little endian format.
	/// TODO: documentation mismatch: there is a problem with the implementation of this characteristic, so we can only send one event tuple at a time
	case clientRequirements = "E95D23C4251D470AA062FA1922DFA9A8"
	/// a writable characteristic which the client may write one or more event structures to, to inform the micro:bit of events which have occurred on the client.
	/// These should be of types indicated in the micro:bit Requirements characteristic bit mask.
	/// struct event {
	/// 	uint16 event_type;
	/// 	uint16 event_value;
	/// };
	case clientEvent = "E95D5404251D470AA062FA1922DFA9A8"

	/// Signed integer 8 bit value in degrees celsius.
	case temperature = "E95D9250251D470AA062FA1922DFA9A8"

	/// Determines the frequency with which temperature data is updated in milliseconds.
	/// TODO: periods do not match with documentation (or no periods documented, but only certain periods allowed)
	case temperaturePeriod = "E95D1B25251D470AA062FA1922DFA9A8"

	/// allows the micro:bit to transmit a byte array containing an arbitrary number of arbitrary octet values to a connected device.
	/// The maximum number of bytes which may be transmitted in one PDU is limited to the MTU minus three or 20 octets to be precise.
	case txCharacteristic = "6E400002B5A3F393E0A9E50E24DCCA9E"
	/// This characteristic allows a connected client to send a byte array containing an arbitrary number of arbitrary octet values to a connected micro:bit.
	/// The maximum number of bytes which may be transmitted in one PDU is limited to the MTU minus three or 20 octets to be precise.
	case rxCharacteristic = "6E400003B5A3F393E0A9E50E24DCCA9E"

	var uuid: CBUUID {
		return rawValue.uuid
	}
}

extension CalliopeService {
	var uuid: CBUUID {
		return rawValue.uuid
	}

	var bitPattern: UInt32 {
		switch self {
		case .interpreter:
			return 1 << 28
		case .notify:
			return 1 << 30
		case .program:
			return 1 << 29
		case .rgbLed:
			return 1 << 0
		case .microphone:
			return 1 << 1
		case .speaker:
			return 1 << 3
		case .brightness:
			return 1 << 2
		case .touchPin:
			return 1 << 9
		case .gesture:
			return 1 << 10
		case .accelerometer:
			return 1 << 8
		case .magnetometer:
			return 1 << 7
		case .button:
			return 1 << 6
		case .led:
			return 1 << 4
		case .event:
			return 1 << 24
		case .temperature:
			return 1 << 5
		default:
			return 0
		}
	}
}

struct CalliopeBLEProfile {

	///standard bluetooth profile of any device: Peripherials contain services which contain characteristics
	///(or included services, but let´s forget about them for now)
	static let serviceCharacteristicMap : [CalliopeService : [CalliopeCharacteristic]] = [
		//master
		.master : [.services],

		//interpreter
		.interpreter : [.program, .notify],

		//interpreter legacy
		.notify : [.notify],
		.program: [.program],

		//custom
		.rgbLed : [.color],
		.microphone : [.noise],
		.speaker : [.playTone],
		.brightness : [.brightness],
		.touchPin : [.touchPin],
		.gesture : [.gesture],

		//microbit profile
		.accelerometer: [.accelerometerData, .accelerometerPeriod],
		.magnetometer: [.magnetometerData, .magnetometerPeriod, .magnetometerBearing],
		.button: [.buttonAState, .buttonBState],
		.ioPin: [.pinData, .pinADConfiguration, .pinIOConfiguration, .pwmControl],
		.led: [.ledMatrixState, .ledText, .scrollingDelay],
		.event: [.microBitRequirements, .microBitEvent, .clientRequirements, .clientEvent],
		.temperature: [.temperature, .temperaturePeriod],
		.uart: [.txCharacteristic, .rxCharacteristic]
	]

	///inverted map of characteristics and corresponding services (there are some ambiguities, which we ignore)
	static let characteristicServiceMap = Dictionary(
		serviceCharacteristicMap.flatMap { (key, value) in value.map { value in (value, key) } },
		uniquingKeysWith: { (first, _) in first })

	///Bluetooth profile with non-human-readable names (same as above, but all UUIDs)
	static let serviceCharacteristicUUIDMap = Dictionary(uniqueKeysWithValues:
		serviceCharacteristicMap.map { ($0.uuid, $1.map { $0.uuid }) })
	
	///To quickly access the characteristic with the corresponding uuid
	static let uuidCharacteristicMap = Dictionary(uniqueKeysWithValues:
		CalliopeCharacteristic.allCases.map { ($0.uuid, $0) })
}

extension CalliopeService {
	static func &(lhs: CalliopeService, rhs: CalliopeService) -> UInt32 {
		return lhs & rhs.bitPattern
	}

	static func &(lhs: UInt32, rhs: CalliopeService) -> UInt32 {
		return lhs & rhs.bitPattern
	}

	static func &(lhs: CalliopeService, rhs: UInt32) -> UInt32 {
		return lhs.bitPattern & rhs
	}

	static func |(lhs: CalliopeService, rhs: CalliopeService) -> UInt32 {
		return lhs | rhs.bitPattern
	}

	static func |(lhs: UInt32, rhs: CalliopeService) -> UInt32 {
		return lhs | rhs.bitPattern
	}

	static func |(lhs: CalliopeService, rhs: UInt32) -> UInt32 {
		return lhs.bitPattern | rhs
	}
}

extension String {
	var uuid: CBUUID {
		if self.count == 32 {
			return CBUUID(hexString: self)
		} else {
			return CBUUID(string: self)
		}
	}
}
