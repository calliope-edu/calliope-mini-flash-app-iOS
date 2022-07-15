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

    var pages: [String] = []

    var pageIndicatorImages = [#imageLiteral(resourceName: "paging_01.pdf"), #imageLiteral(resourceName: "paging_02.pdf")]
    
    var loadedControllers: [OnboardingController] = []
    
    var currentIndex = 0 {
        didSet {
            navigatingBackwards = false
            UIView.transition(with: pageIndicator, duration: 0.2, options: .transitionCrossDissolve, animations: {
                self.pageIndicator.image = self.pageIndicatorImages[self.currentIndex]
            }, completion: nil)
        }
    }

    public var pageIndicator: UIImageView!
    
    private var viewControllersObservation: NSKeyValueObservation?
    
    init?(coder: NSCoder, pageIndicator: UIImageView, pages: [String]) {
        self.pageIndicator = pageIndicator
        self.pages = pages
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        if #available(iOS 13.0, *) {
            fatalError("init with coder for onboardingcontroller not implemented in ios13")
        }
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        super.viewDidLoad()
        
        viewControllersObservation = observe(\.viewControllers, changeHandler: { [weak self] (_, _) in
            NSLog("view controllers: \(self?.viewControllers ?? [])")
        })
        
        if pages.count > pageIndicatorImages.count {
            fatalError("there must be at least as many page indicators as tutorial pages!")
        }
        
        let firstViewController = loadController(0)
        loadedControllers.append(firstViewController)
        self.setViewControllers([firstViewController], direction: .forward, animated: true, completion: nil)
        
        self.dataSource = self
        self.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MatrixConnectionViewController.instance?.connectionDescriptionText = NSLocalizedString("Connect to a calliope to finish the tutorial", comment: "")
        MatrixConnectionViewController.instance?.calliopeClass = FlashableCalliope.self
    }
    
    //MARK: pageviewcontroller data source
    
    //this variable is temporarily disabling the reset of the datasource when blocking forward continuation
    var navigatingBackwards = false
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? UIViewController & OnboardingPage
            else { fatalError("viewcontrollers for this onboarding have to be of type onboardingPage!") }
        let index = indexOf(loadedController: viewController)
        if index > 0 {
            navigatingBackwards = true
            return loadedControllers[index - 1]
        } else {
            return nil
        }
    }
        
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? UIViewController & OnboardingPage
            else { fatalError("viewcontrollers for this onboarding have to be of type onboardingPage!") }
        
        let currentIndex = indexOf(loadedController: viewController)
        //TODO: use taskCompleted to change indicator of successful or insuccessful completion.
        let (_, canProceed) = viewController.attemptProceed()
        if !canProceed {
            if (!navigatingBackwards) {
                forgetBlockedContinuation(pageViewController)
            }
            return nil
        }
        
        return nextController(currentIndex)
    }
    
    private func indexOf(loadedController: UIViewController & OnboardingPage) -> Int {
        guard let index = loadedControllers.firstIndex(where: { controller in
            loadedController == (controller as UIViewController) }) else {
                fatalError("To load a viewcontroller after some other viewcontroller, the other viewcontroller should have been loaded already")
        }
        return index
    }

    private func nextController(_ currentIndex: Int) -> UIViewController? {
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
        guard var controller = self.storyboard?.instantiateViewController(withIdentifier: pages[index]) as? OnboardingController else {
            fatalError("Only ViewControllers conforming to OnboardingPage allowed as pages of Onboarding ViewController")
        }
        controller.delegate = self
        return controller
    }
    
    private func forgetBlockedContinuation(_ pageViewController: UIPageViewController) {
        //this is a hack to make the page view controller forget our decision
        pageViewController.dataSource = nil
        delay(time: 0.2) {
            pageViewController.dataSource = self
        }
    }

    //MARK: pageviewcontroller delegate methods
    
    var previousIndex = 0
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        NSLog("will transition to \(pendingViewControllers)")
        
        let index = indexOf(loadedController: pendingViewControllers[0] as! UIViewController & OnboardingPage)
        
        previousIndex = currentIndex
        currentIndex = index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        NSLog("finished animating \(completed)")
        
        if !completed {
            currentIndex = previousIndex
        }
    }
    
    //MARK: OnboardingPageDelegate
    
    func proceed(from page: UIViewController & OnboardingPage, completed: Bool) {
        let index = indexOf(loadedController: page)
        guard let nextPage = nextController(index) else { return }
        self.currentIndex = index + 1
        self.setViewControllers([nextPage], direction: .forward, animated: true, completion: nil)
    }
}
