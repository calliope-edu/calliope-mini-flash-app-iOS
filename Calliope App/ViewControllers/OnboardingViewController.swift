//
//  OnboardingViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 13.07.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

class OnboardingViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    var pages = ["tutorial1", "tutorial2", "tutorial3"]
    var loadedControllers: [UIViewController] = []

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
        guard let currentIndex = loadedControllers.firstIndex(of: viewController) else { return nil }
        if currentIndex > 0 {
            return loadedControllers[currentIndex - 1]
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = loadedControllers.firstIndex(of: viewController) else { fatalError("To load a viewcontroller after some other viewcontroller, the other viewcontroller should have been loaded already") }
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

    private func loadController(_ index: Int) -> UIViewController {
        return UIStoryboard(name: "HomeScreen", bundle: nil).instantiateViewController(withIdentifier: pages[index])
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
