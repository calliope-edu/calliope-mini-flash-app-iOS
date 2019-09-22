//
//  OnboardingViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 13.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class OnboardingViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, OnboardingPageDelegate {
    
    
    typealias OnboardingController = UIViewController & OnboardingPage

    var pages = ["tutorial_connect_battery", "tutorial_connect_bluetooth", "tutorial2", "tutorial3"]
    var loadedControllers: [OnboardingController] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        MatrixConnectionViewController.instance?.connectionDescriptionText = "ConnectionDescriptionText for tutorial"
        MatrixConnectionViewController.instance?.connector = CalliopeBLEDiscovery({ (peripheral, name) -> CalliopeBLEDevice in
            return ApiCalliope(peripheral: peripheral, name: name) })
        
        let firstViewController = loadController(0)
        loadedControllers.append(firstViewController)
        self.setViewControllers([firstViewController], direction: .forward, animated: true, completion: nil)
        
        self.dataSource = self
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = loadedControllers.firstIndex(where: { controller in
            viewController == (controller as UIViewController)
        }) else { return nil }
        if currentIndex > 0 {
            return loadedControllers[currentIndex - 1]
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? UIViewController & OnboardingPage,
            let currentIndex = loadedControllers.firstIndex(where: { controller in
                viewController == (controller as UIViewController)
            }) else { fatalError("To load a viewcontroller after some other viewcontroller, the other viewcontroller should have been loaded already") }
        
        let (taskCompleted, canProceed) = viewController.attemptProceed()
        if !canProceed {
            //this is a hack to make the page view controller forget our decision
            pageViewController.dataSource = nil
            delay(time: 0.1) {
                pageViewController.dataSource = self
            }
            return nil
        }
        
        if currentIndex < loadedControllers.count - 1 {
            return loadedControllers[currentIndex + 1]
        } else if (currentIndex < pages.count - 1) {
            let nextController = loadController(currentIndex + 1)
            loadedControllers.append(nextController)
            return nextController
        } else {
            return nil
        }
    }

    private func loadController(_ index: Int) -> OnboardingController {
        guard var controller = UIStoryboard(name: "Onboarding", bundle: nil).instantiateViewController(withIdentifier: pages[index]) as? OnboardingController else {
            fatalError("Only ViewControllers conforming to OnboardingPage allowed as pages of Onboarding ViewController")
        }
        controller.delegate = self
        return controller
    }
    
    func proceed(from page: OnboardingPage, completed: Bool) {
        guard let currentPage = page as? UIViewController,
            let nextPage = pageViewController(self, viewControllerAfter: currentPage) else {
            return
        }
        self.setViewControllers([nextPage], direction: .forward, animated: true, completion: nil)
    }

}
