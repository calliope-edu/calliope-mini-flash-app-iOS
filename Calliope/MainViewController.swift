import UIKit

final class MainViewController: UIViewController {
    
    // MARK: - UIElemets
    private let viewLogo = UIImageView()
    private let viewImageL = UIImageView()
    private let viewImageR = UIImageView()
    private let labelWelcome = UILabel()
    private let viewArrow = UIImageView()
    private let buttonScanner = UIButton()
    private let buttonEditors = UIButton()
    private let buttonHistory = UIButton()
    
    // MARK- Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        
        view.backgroundColor = Styles.colorWhite
        
        addHelpButton()
        
        viewLogo.image = UIImage(named: "WelcomeLogo") ?? UIImage()
        viewLogo.contentMode = .scaleAspectFit
        view.addSubview(viewLogo)
        
        viewImageL.image = UIImage(named: "DotsL") ?? UIImage()
        viewImageL.contentMode = .scaleAspectFit
        view.addSubview(viewImageL)
        
        viewImageR.image = UIImage(named: "DotsR") ?? UIImage()
        viewImageR.contentMode = .scaleAspectFit
        view.addSubview(viewImageR)
        
        labelWelcome.text = "main.text.none".localized
        labelWelcome.numberOfLines = 0
        labelWelcome.textAlignment = .center
        labelWelcome.font = Styles.defaultFont(size: range(15...35))
        labelWelcome.textColor = Styles.colorGray
        view.addSubview(labelWelcome)
        
        viewArrow.image = UIImage(named: "Arrow")?.imageTinted(Styles.colorYellow)
        viewArrow.contentMode = .scaleAspectFit
        view.addSubview(viewArrow)
        
        setup(button: buttonScanner,
              title: "main.scanner.none".localized,
              image: UIImage(named: "IconBluetooth") ?? UIImage(),
              color: Styles.colorYellow)
        buttonScanner.addAction(for: .touchUpInside, actionScanner)
        view.addSubview(buttonScanner)
        
        setup(button: buttonEditors,
              title: "main.editors".localized,
              image: UIImage(named: "IconCode") ?? UIImage(),
              color: Styles.colorGreen)
        buttonEditors.addAction(for: .touchUpInside, actionEditors)
        view.addSubview(buttonEditors)
        
        setup(button: buttonHistory,
              title: "main.history".localized,
              image: UIImage(named: "IconDevice") ?? UIImage(),
              color: Styles.colorBlue)
        buttonHistory.addAction(for: .touchUpInside, actionHistory)
        view.addSubview(buttonHistory)
        layout()
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        let settingsBarItem = UIBarButtonItem(title: "main.settings".localized,
                                              style: .done,
                                              target: self,
                                              action: #selector(showSettings))
        
        navigationItem.leftBarButtonItem = settingsBarItem
        
        navigationItem.title = ""
    }
    
    private func setup(button: UIButton, title: String, image: UIImage, color: UIColor) {
        let left = range(-40...140)
        let spaceX = range(-40...40)
        let marginY = range(20...60)
        button.setTitle(title, for: .normal)
        button.setTitleColor(Styles.colorWhite, for: .normal)
        button.titleLabel?.font = Styles.defaultFont(size: range(20...42))
        button.titleEdgeInsets = UIEdgeInsets.init(top: 0.0, left: spaceX, bottom: 0.0, right: 0.0)
        button.setImage(image.imageTinted(Styles.colorWhite), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets.init(top: marginY, left: 0.0, bottom: marginY, right: 0.0)
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets.init(top: 0.0, left: left, bottom: 0.0, right: 0.0)
        button.backgroundColor = color
        button.sizeToFit()
    }
    
    func layout() {
        let superview = view!
        
        let marginX = range(20...40)
        let spaceY = range(35...80)
        
        guard let image = viewLogo.image else { return }
        let imageRatio = image.size.height/image.size.width
        
        viewLogo.snp.makeConstraints { make in
            make.centerX.equalTo(superview)
            make.top.equalTo(superview).offset(spaceY)
            make.width.equalTo(superview).multipliedBy(0.35)
            make.height.equalTo(viewLogo.snp.width).multipliedBy(imageRatio)
        }
        
        labelWelcome.snp.makeConstraints { make in
            make.centerX.equalTo(superview)
            make.top.equalTo(viewLogo.snp.bottom).offset(spaceY)
            make.width.equalTo(superview).multipliedBy(0.6)
        }
        
        let imageAnchor = labelWelcome
        let imageDistance = marginX*1.5
        
        guard let dotsL = viewImageL.image else { return }
        let dotsLRatio = dotsL.size.height/dotsL.size.width
        viewImageL.snp.makeConstraints { make in
            make.right.equalTo(imageAnchor.snp.left).offset(imageDistance)
            make.centerY.equalTo(imageAnchor)
            make.width.equalTo(superview).multipliedBy(0.35)
            make.height.equalTo(viewImageL.snp.width).multipliedBy(dotsLRatio)
        }
        
        guard let dotsR = viewImageR.image else { return }
        let dotsRRatio = dotsR.size.height/dotsR.size.width
        viewImageR.snp.makeConstraints { make in
            make.left.equalTo(imageAnchor.snp.right).offset(-imageDistance)
            make.centerY.equalTo(imageAnchor)
            make.width.equalTo(superview).multipliedBy(0.35)
            make.height.equalTo(viewImageR.snp.width).multipliedBy(dotsRRatio)
        }
        
        viewArrow.snp.makeConstraints { make in
            make.centerX.equalTo(superview)
            make.bottom.equalTo(buttonScanner.snp.top).offset(1)
            make.width.equalTo(superview).multipliedBy(0.065)
            make.height.equalTo(viewArrow.snp.width).multipliedBy(50.3/143.5)
        }
        
        buttonScanner.snp.makeConstraints { make in
            make.left.right.equalTo(superview)
            make.height.equalTo(superview).multipliedBy(0.15)
            make.top.equalTo(labelWelcome.snp.bottom).offset(spaceY)
        }
        
        buttonEditors.snp.makeConstraints { make in
            make.left.right.height.equalTo(buttonScanner)
            make.top.equalTo(buttonScanner.snp.bottom)
        }
        
        buttonHistory.snp.makeConstraints { make in
            make.left.right.height.equalTo(buttonScanner)
            make.top.equalTo(buttonEditors.snp.bottom)
            make.bottom.equalTo(superview.snp.bottom)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let device = Device.current {
            let name = device.name.slice(from: "[", to: "]") ?? device.name
            let text = String(format:"main.text.selected".localized, name)
            labelWelcome.text = text
            
            let title = "main.scanner.selected".localized
            buttonScanner.setTitle(title, for: .normal)
        } else {
            labelWelcome.text = "main.text.none".localized
            
            let title = "main.scanner.none".localized
            buttonScanner.setTitle(title, for: .normal)
        }
    }
    
    func actionScanner(button: UIButton) {
        let vc = ScannerViewController()
        let nc = UINavigationController(rootViewController: vc)
        nc.modalTransitionStyle = .coverVertical
        present(nc, animated: true)
    }
    
    func actionEditors(button: UIButton) {
        let vc = EditorsViewController()
        if let navigationController = self.navigationController {
            navigationController.pushViewController(vc, animated: true)
        }
    }
    
    func actionHistory(button: UIButton) {
        let vc = HistoryViewController()
        if let navigationController = self.navigationController {
            navigationController.pushViewController(vc, animated: true)
        }
    }
    
    @objc func showSettings() {
        let settingsViewController = SettingsViewController()
        let navigationController = UINavigationController()
        navigationController.viewControllers = [settingsViewController]
        present(navigationController, animated: true, completion: nil)
    }
    
}

