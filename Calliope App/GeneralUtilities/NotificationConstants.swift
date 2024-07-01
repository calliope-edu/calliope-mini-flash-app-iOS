//
//  NotificationConstants.swift
//  Calliope
//
//  Created by Tassilo Karge on 16.06.19.
//

import Foundation

public struct NotificationConstants {
	public static let hexFileChanged = NSNotification.Name(rawValue: "calliope.hexfiles.changed")
    public static let projectsChanged = NSNotification.Name(rawValue: "calliope.projects.changed")
    public static let calliopeConnected = NSNotification.Name(rawValue: "calliope.bluetooth.connected")
}
