import UIKit

final class EditorsViewController: UIViewController {

    // MARK: - UIElements
    private let labelText = UILabel()
    private var robertaView: UIView!
    private var makeCodeView: UIView!
    private var calliopeView: UIView!

    // MAKR: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layout()
    }

    // MARK: - Setup
    private func setup() {
        // NavigationBar
        addHelpButton()
        navigationItem.title = "editors.title".localized
        // View
        view.backgroundColor = Styles.colorWhite
        // LabelText
        labelText.text = "editors.text".localized
        labelText.numberOfLines = 0
        labelText.font = Styles.defaultFont(size: range(15...35))
        labelText.textColor = Styles.colorGray
        
        // RobertaView
        robertaView = ButtonView(title: "editor.roberta.name".localized,
                                 subtitle: "editors.button".localized,
                                 icon: UIImage(named:"IconCode"),
                                 color: Styles.colorBlue) { [weak self] in
                                    self?.robertaButtonPressed()
        }
        // RobertaView
        makeCodeView = ButtonView(title: "editor.microbit.name".localized,
                                 subtitle: "editors.button".localized,
                                 icon: UIImage(named:"IconCode"),
                                 color: Styles.colorGreen) { [weak self] in
                                    self?.makeCodeButtonPressed()
        }
        // CalliopeVIew
        calliopeView = ButtonView(title: "editor.mini.name".localized,
                                  subtitle: "editors.button".localized,
                                  icon: UIImage(named:"IconCode"),
                                  color: Styles.colorYellow) { [weak self] in
                                    self?.calliopeButtonPressed()
        }
    }
    
    func layout() {
        // Constants
        var buttonHeight = view.frame.height
        if  #available(iOS 11.0, *) {
            buttonHeight -= view.safeAreaInsets.top + view.safeAreaInsets.bottom
        }
        buttonHeight = buttonHeight / 5
        // RobertaView
        view.addSubview(robertaView)
        robertaView.snp.remakeConstraints { (make) in
            make.bottom.right.equalToSuperview().offset(range(-20,-40))
            make.left.equalToSuperview().offset(range(20,40))
            make.height.lessThanOrEqualTo(buttonHeight)
        }
        // MakeCodeView
        view.addSubview(makeCodeView)
        makeCodeView.snp.remakeConstraints { (make) in
            make.bottom.equalTo(robertaView.snp.top).offset(range(-20,-40))
            make.right.equalToSuperview().offset(range(-20,-40))
            make.left.equalToSuperview().offset(range(20,40))
            make.height.lessThanOrEqualTo(buttonHeight)
        }
        // CalliopeView
        view.addSubview(calliopeView)
        calliopeView.snp.remakeConstraints { (make) in
            make.bottom.equalTo(makeCodeView.snp.top).offset(range(-20,-40))
            make.right.equalToSuperview().offset(range(-20,-40))
            make.left.equalToSuperview().offset(range(20,40))
            make.height.lessThanOrEqualTo(buttonHeight)
        }
        // Label
        view.addSubview(labelText)
        labelText.snp.remakeConstraints { (make) in
            make.top.left.equalToSuperview().offset(range(20,40))
            make.right.equalToSuperview().offset(range(-20,-40))
            make.bottom.greaterThanOrEqualTo(calliopeView.snp.top).offset(range(-20,-40))
        }
    }
  
    // MARK: - User interaction
    private func calliopeButtonPressed() {
        actionEditor(editor: MiniEditor())
    }

    private func makeCodeButtonPressed() {
        actionEditor(editor: MicrobitEditor())
    }

    private func robertaButtonPressed() {
        actionEditor(editor: RobertaEditor())
    }

    private func actionEditor(editor:Editor) {
        let vc = EditorViewController()
        vc.editor = editor
        if let navigationController = self.navigationController {
            navigationController.pushViewController(vc, animated: true)
        }
    }
}
