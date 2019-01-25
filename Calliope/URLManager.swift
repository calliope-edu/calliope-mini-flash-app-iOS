//
//  SettingsViewModel.swift
//  Calliope
//
//  Created by Benedikt Spohr on 1/24/19.
//

import Foundation

/// Saves the urls that the editors will call
class URLManager {
    
    private static let calliopeDefault = "https://miniedit.calliope.cc"
    private static let makeCodeDefault = "https://makecode.calliope.cc/"
    private static let robertaDefault = "https://lab.open-roberta.org/#loadSystem&&calliope2017"
    
    /// Url for the Calliope mini editor
    ///
    /// Vars will be saved in the user defaults
    static var calliopeUrl: String? {
        set {
            UserDefaults.standard.set(newValue, forKey: "urlStettings_calliopeUrl")
        }
        get {
            return UserDefaults.standard.string(forKey: "urlStettings_calliopeUrl") ??
                URLManager.calliopeDefault
        }
    }
    
    /// Url for the MakeCode editor
    ///
    /// Vars will be saved in the user defaults
    static var makeCodeUrl: String? {
        set {
            UserDefaults.standard.set(newValue, forKey: "urlStettings_makeCodeUrl")
        }
        get {
            return UserDefaults.standard.string(forKey: "urlStettings_makeCodeUrl") ??
            URLManager.makeCodeDefault
        }
    }
    
    /// Url for the Open Roberta NEOP® editor
    ///
    /// Vars will be saved in the user defaults
    static var  robertaUrl: String? {
        set {
            UserDefaults.standard.set(newValue, forKey: "urlStettings_robertaUrl")
        }
        get {
            return UserDefaults.standard.string(forKey: "urlStettings_robertaUrl") ??
            URLManager.robertaDefault
        }
    }
    
    
    /// Restore the default urls
    static func restoreValues() {
        calliopeUrl = nil
        makeCodeUrl = nil
        robertaUrl = nil
    }
    
    /// Saves the url to the user defaults
    ///
    /// Nil value will reset the url to default
    /// - Parameters:
    ///   - calliope: calliope url
    ///   - makeCode: make url
    ///   - roberta: roberta url
    static func save(calliope: String?, makeCode: String?, roberta: String?) {
        calliopeUrl = calliope
        makeCodeUrl = makeCode
        robertaUrl = roberta
    }
}
