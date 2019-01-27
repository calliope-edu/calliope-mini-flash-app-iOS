import UIKit

final class EditorsViewController: BaseViewController {

    private let labelText = UILabel()
    
    private let buttonEditorMini = UIButton()
    private let buttonEditorMicrobit = UIButton()
    private let buttonEditorRoberta = UIButton()

    private func setup(button: UIButton, name: String, text: String, color: UIColor) {

        let cornerRadius = range(8...20)
        let roundedView = UIView()
        roundedView.backgroundColor = color
        roundedView.layer.cornerRadius = cornerRadius
        roundedView.isExclusiveTouch = false
        roundedView.isUserInteractionEnabled = false
        button.addSubview(roundedView)
        roundedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let nameLabel = UILabel()
        nameLabel.numberOfLines = 1
        nameLabel.font = Styles.defaultFont(size: range(15...35))
        nameLabel.textColor = Styles.colorWhite
        nameLabel.text = name
        roundedView.addSubview(nameLabel)

        let lineView = UIView()
        lineView.backgroundColor = Styles.colorWhite
        roundedView.addSubview(lineView)

        let image = UIImage(named:"IconCode") ?? UIImage()
        let iconView = UIImageView()
        iconView.image = image.imageTinted(Styles.colorWhite)
        iconView.contentMode = .scaleAspectFit
        roundedView.addSubview(iconView)

        let actionLabel = UILabel()
        actionLabel.text = "editors.button".localized
        actionLabel.font = Styles.defaultFont(size: range(15...35))
        actionLabel.numberOfLines = 1
        actionLabel.textColor = Styles.colorWhite
        roundedView.addSubview(actionLabel)

        let superview = roundedView

        let imageRatio = image.size.height/image.size.width

        let marginX = range(20...40)
        let marginY = marginX
        let spaceY = range(20...21)
        let marginButtonX = range(40...250)

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(superview).offset(marginY)
            make.left.equalTo(superview).offset(marginX)
            make.right.equalTo(superview).offset(-marginX)
        }

        lineView.snp.makeConstraints { make in
            make.left.right.equalTo(nameLabel)
            make.height.equalTo(1)
            make.top.equalTo(nameLabel.snp.bottom).offset(spaceY)
        }

        iconView.snp.makeConstraints { make in
            make.top.equalTo(lineView.snp.bottom).offset(spaceY)
            make.left.equalTo(marginButtonX)
            make.bottom.equalTo(superview).offset(-marginY)
            make.width.equalTo(superview).multipliedBy(0.1)
            make.height.equalTo(iconView.snp.width).multipliedBy(imageRatio)
        }

        actionLabel.snp.makeConstraints { make in
            make.left.equalTo(iconView.snp.right).offset(marginX)
            make.right.equalTo(superview).offset(marginX)
            make.centerY.equalTo(iconView)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "editors.title".localized
        view.backgroundColor = Styles.colorWhite

        let buttonHelp = createHelpButton()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView:buttonHelp)

        labelText.text = "editors.text".localized
        labelText.numberOfLines = 0
        labelText.font = Styles.defaultFont(size: range(15...35))
        labelText.textColor = Styles.colorGray
        view.addSubview(labelText)

        setup(button: buttonEditorMini,
              name: "editor.mini.name".localized,
              text: "editor.mini.text".localized,
              color: Styles.colorYellow)
        buttonEditorMini.addAction(for: .touchUpInside, actionEditorMini)
        view.addSubview(buttonEditorMini)

        setup(button: buttonEditorMicrobit,
              name: "editor.microbit.name".localized,
              text: "editor.microbit.text".localized,
              color: Styles.colorGreen)
        buttonEditorMicrobit.addAction(for: .touchUpInside, actionEditorMicrobit)
        view.addSubview(buttonEditorMicrobit)

        setup(button: buttonEditorRoberta,
              name: "editor.roberta.name".localized,
              text: "editor.roberta.text".localized,
              color: Styles.colorBlue)
        buttonEditorRoberta.addAction(for: .touchUpInside, actionEditorRoberta)
        view.addSubview(buttonEditorRoberta)

        layout()
    }

    func layout() {
        let superview = view!

        let marginX = range(20...40)
        let marginY = marginX
        let spacingY = range(20...40)

        labelText.snp.makeConstraints { make in
            make.top.equalTo(superview).offset(marginY)
            make.left.equalTo(superview).offset(marginX)
            make.right.equalTo(superview).offset(-marginX)
        }
        labelText.setContentCompressionResistancePriority(.required, for: .vertical)

        buttonEditorMini.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(labelText.snp.bottom).offset(spacingY)
            make.left.equalTo(superview).offset(marginX)
            make.right.equalTo(superview).offset(-marginX)
        }
        buttonEditorMicrobit.snp.makeConstraints { make in
            make.top.equalTo(buttonEditorMini.snp.bottom).offset(spacingY)
            make.left.right.height.equalTo(buttonEditorMini)
        }
        buttonEditorRoberta.snp.makeConstraints { make in
            make.top.equalTo(buttonEditorMicrobit.snp.bottom).offset(spacingY)
            make.left.right.height.equalTo(buttonEditorMini)
            make.bottom.equalTo(superview.snp.bottom).offset(-marginX)
        }
    }

    func actionEditorMini(button: UIButton) {
        actionEditor(editor: MiniEditor())
    }

    func actionEditorMicrobit(button: UIButton) {
        actionEditor(editor: MicrobitEditor())
    }

    func actionEditorRoberta(button: UIButton) {
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
