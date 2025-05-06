//
//  Coordinates+Extension.swift
//  Calliope App
//
//  Created by Calliope on 06.05.25.
//  Copyright © 2025 calliope. All rights reserved.
//

import Foundation
import CoreLocation

extension CLLocationCoordinate2D {
    func rounded(toPlaces places:Int) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude.rounded(toPlaces: places), longitude: self.longitude.rounded(toPlaces: places))
    }
}


extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D {
    init?(latitude: CLLocationDegrees?, longitude: CLLocationDegrees?) {
        guard let latitude = latitude, let longitude = longitude else {
            return nil
        }
        self.init(latitude: latitude, longitude: longitude)
    }
}
