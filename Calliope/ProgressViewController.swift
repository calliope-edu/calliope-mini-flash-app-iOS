import UIKit

enum ProgressViewControllerState {
    case progress
    case success
    case error
}

struct ProgressViewControllerModel {
    var state: ProgressViewControllerState = .progress
    var progress: Float = 0
    var heading = ""
    var text = ""
    var button = ""
    var interaction = false
}

struct Animation {
    let images: [UIImage]
    let duration: TimeInterval
    let repeatCount: Int
}

class ProgressViewController: UIViewController {

    public var buttonPressAction: ((ProgressViewControllerState)->())? = nil

    private var model = ProgressViewControllerModel()

    private static func createImages(folder: String, count: Int) -> [UIImage] {
        var images = [UIImage]()
        for i in 1..<count+1 {
            let name = String(format:"%@/%04d", folder, i)
            images.append(UIImage(named: name)?.imageTinted(Styles.colorWhite) ?? UIImage())
        }
        return images
    }

    private let animationProgress = Animation(
        images: createImages(folder:"AnimProgress", count:20),
        duration: 2.5, repeatCount: -1)

    private let animationSuccess = Animation(
        images: createImages(folder:"AnimSuccess", count:20),
        duration: 1, repeatCount: -1)

    private let animationError = Animation(
        images: createImages(folder:"AnimError", count:20),
        duration: 1, repeatCount: -1)

    public func update(animated:Bool, _ block:@escaping (inout ProgressViewControllerModel)->()) {
        if (!animated) { UIView.setAnimationsEnabled(false) }

        var newModel = model
        block(&newModel)

        if newModel.state != model.state || !animated {
            var backgroundColor: UIColor {
                switch(newModel.state) {
                case .progress: return Styles.colorGreen
                case .success: return Styles.colorGreen
                case .error: return Styles.colorRed
                }
            }
            var animation: Animation {
                switch(newModel.state) {
                case .progress: return animationProgress
                case .success: return animationSuccess
                case .error: return animationError
                }
            }
            UIView.transition(with: imageView,
              duration: 0.5,
              options: .transitionCrossDissolve,
              animations: {
                self.imageView.animationImages = animation.images
                self.imageView.animationDuration = animation.duration
                self.imageView.animationRepeatCount = animation.repeatCount
                self.imageView.startAnimating()
              })

            UIView.animate(withDuration: 0.5, animations: {
                self.view.backgroundColor = backgroundColor
            })
        }

        var progress: Float {
            switch(newModel.state) {
            case .progress: return newModel.progress
            case .success: return 1
            case .error: return 0
            }
        }

        if progress != model.progress || !animated {
            UIView.animate(withDuration: 0.5, animations: {
                self.progressView.progress = progress
            })
        }

        if newModel.heading != model.heading || !animated {
            UIView.transition(with: labelHeading,
              duration: 0.2,
              options: .transitionCrossDissolve,
              animations: {
                self.labelHeading.text = newModel.heading
              })
        }

        if newModel.text != model.text || !animated {
            UIView.transition(with: labelText,
              duration: 0.2,
              options: .transitionCrossDissolve,
              animations: {
                self.labelText.text = newModel.text
              })
        }

        if newModel.button != model.button || !animated {
            UIView.transition(with: button,
              duration: 0.2,
              options: .transitionCrossDissolve,
              animations: {
                self.button.setTitle(newModel.button, for: .normal)
              })
        }

        if newModel.interaction != model.interaction || !animated {
            UIView.transition(with: button,
              duration: 0.2,
              options: .transitionCrossDissolve,
              animations: {
                self.button.isHidden = !newModel.interaction
              })
        }

        if (!animated) { UIView.setAnimationsEnabled(true) }
        model = newModel
    }

    private let imageView = UIImageView()
    private let progressView = UIProgressView()
    private let labelHeading = UILabel()
    private let labelText = UILabel()
    private let button = UIButton()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)

        progressView.progressViewStyle = .bar
        progressView.tintColor = Styles.colorWhite
        progressView.progress = 0
        view.addSubview(progressView)

        labelHeading.numberOfLines = 0
        labelHeading.textColor = Styles.colorWhite
        labelHeading.font = Styles.defaultFont(size: range(20...45))
        view.addSubview(labelHeading)

        labelText.numberOfLines = 0
        labelText.textColor = Styles.colorWhite
        labelText.font = Styles.defaultFont(size: range(20...45))
        view.addSubview(labelText)

        unowned let me = self
        button.setTitleColor(Styles.colorWhite, for: .normal)
        button.titleLabel?.font = Styles.defaultFont(size: range(18...42))
        button.backgroundColor = Styles.colorYellow
        button.addAction(for: .touchUpInside) { _ in
            switch(me.model.state) {
            case .progress:
                me.dismiss(animated: true)
            case .success:
                if let presenter = me.presentingViewController {
                    presenter.dismiss(animated: true)
                } else {
                    ERR("no presenting view controller - this should never happen")
                }
            case .error:
                me.dismiss(animated: true)
            }
            me.buttonPress(me.model.state)
        }
        view.addSubview(button)

        layout()

        DispatchQueue.main.async {
            self.work()
        }
    }

    func layout() {
        let superview = view!

        let margin = range(20...170)
        let spacingY = range(20...40)
        let height = range(70...170)

        let imageRatio = 1.0/1.0

        imageView.snp.makeConstraints { make in
            make.centerX.equalTo(superview)
            make.bottom.equalTo(progressView.snp.top).offset(-spacingY*2)
            make.width.equalTo(progressView).multipliedBy(0.5)
            make.height.equalTo(imageView.snp.width).multipliedBy(imageRatio)
        }

        progressView.snp.makeConstraints { make in
            make.left.equalTo(superview).offset(margin)
            make.right.equalTo(superview).offset(-margin)
            make.centerY.equalTo(superview).offset(2*spacingY)
            make.height.equalTo(2)
        }

        labelHeading.snp.makeConstraints { make in
            make.top.lessThanOrEqualTo(progressView.snp.bottom).offset(spacingY)
            make.left.equalTo(superview).offset(margin)
            make.right.equalTo(superview).offset(-margin)
        }

        labelText.setContentHuggingPriority(.required, for: .vertical)
        labelText.snp.makeConstraints { make in
            make.top.equalTo(labelHeading.snp.bottom).offset(spacingY)
            make.bottom.greaterThanOrEqualTo(button.snp.top).offset(range(-20, -40))
            make.left.right.equalTo(labelHeading)
        }

        button.snp.makeConstraints { make in
            make.left.right.equalTo(superview)
            make.height.equalTo(height)
            make.bottom.equalTo(superview)
        }
    }

    func work() {
    }

    func buttonPress(_ state: ProgressViewControllerState) {
        if let action = buttonPressAction {
            action(model.state)
        }
    }

}

