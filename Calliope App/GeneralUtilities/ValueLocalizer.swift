//
//  ValueLocalizer.swift
//  Book_Sources
//
//  Created by Tassilo Karge on 15.11.18.
//

import UIKit

class ValueLocalizer: NSObject {

    public static let current = ValueLocalizer()

    private let locale = NSLocale.current
    private let measurementFormatter = MeasurementFormatter()

    private let calliopeTemperatureUnit = UnitTemperature.celsius
    private lazy var localTemperatureUnit : UnitTemperature = self.detectTemperatureSetting()

    private override init() {
        super.init()
        measurementFormatter.locale = locale
    }

    /// Finds out what the user has set for the desired temperature unit
    /// This seems not to be possible directly - because the API for the setting is private.
    /// Instead, we use the measurementFormatter, which uses the setting to add a unit symbol,
    /// which we can then detect inside the formatted string
    ///
    /// - Returns: the temperature unit set in the device settings
    private func detectTemperatureSetting() -> UnitTemperature {

        //create a random measurement with an arbitrary unit
        let dummyTemperature = Measurement(value: 10.0, unit: calliopeTemperatureUnit)

        //let the measurementFormatter do its thing to add a unit symbol (e.g. °C)
        let localizedMeasurementString = measurementFormatter.string(from: dummyTemperature)

        //detect the unit symbol and conclude the user-set temperature unit
        if localizedMeasurementString.contains("C") {
            return UnitTemperature.celsius
        } else if localizedMeasurementString.contains("F") {
            return UnitTemperature.fahrenheit
        } else {
            return UnitTemperature.kelvin
        }
    }

	//MARK: methods to convert values to and from currently set unit

    /// Converts from the temperature unit of the calliope to the user´s unit
    ///
    /// - Parameter unlocalized: the temperature value as measured by the calliope
    /// - Returns: the temperature value in a unit that user is supposed to see
    public func localizeTemperature(unlocalized: Double) -> Double {
        let unlocalizedMeasurement = Measurement(value: unlocalized, unit: calliopeTemperatureUnit)
        return unlocalizedMeasurement.converted(to: localTemperatureUnit).value
    }

    /// Converts from the temperature unit of the user to the calliope´s unit
    ///
    /// - Parameter localized: the temperature value as input or seen by the user
    /// - Returns: the temperature value in the unit that the calliope uses
    public func delocalizeTemperature(localized: Double) -> Double {
        let localizedMeasurement = Measurement(value: localized, unit: localTemperatureUnit)
        return localizedMeasurement.converted(to: calliopeTemperatureUnit).value
    }

    public func localizedTemperatureString(unlocalizedValue: Double) -> String {
        let unlocalizedMeasurement = Measurement(value: unlocalizedValue, unit: calliopeTemperatureUnit)
        return measurementFormatter.string(from: unlocalizedMeasurement)
    }
}
