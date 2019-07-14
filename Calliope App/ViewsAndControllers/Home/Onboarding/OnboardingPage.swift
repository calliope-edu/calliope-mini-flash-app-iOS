//
//  OnboardingPage.swift
//  Calliope App
//
//  Created by Tassilo Karge on 14.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import Foundation

protocol OnboardingPage {
    var delegate: OnboardingPageDelegate? { get set }
    //returns whether proceeding is allowed or not, and whether the task was completed
    func attemptProceed() -> (Bool, Bool)
}

protocol OnboardingPageDelegate {
    //tells the delegate to proceed and whether or not the task was completed
    func proceed(from page: OnboardingPage, completed: Bool)
}
