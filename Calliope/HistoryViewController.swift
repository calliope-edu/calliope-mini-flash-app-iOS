import UIKit

final class HistoryTableViewCell: UITableViewCell {

    private let rounded = UIView()

    public let filenameLabel = UILabel()
    public let dateLabel = UILabel()

    private let iconView = UIImageView()
    private let actionLabel = UILabel()

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        let cornerRadius = range(8...20)

        rounded.layer.cornerRadius = cornerRadius
        contentView.addSubview(rounded)

        filenameLabel.numberOfLines = 1
        filenameLabel.font = Styles.defaultFont(size: range(15...35))
        filenameLabel.textColor = Styles.colorWhite
        rounded.addSubview(filenameLabel)

        dateLabel.numberOfLines = 2
        dateLabel.font = Styles.defaultFont(size: range(15...35))
        dateLabel.textColor = Styles.colorWhite
        rounded.addSubview(dateLabel)

        let lineView = UIView()
        lineView.backgroundColor = Styles.colorWhite
        rounded.addSubview(lineView)

        let image = UIImage(named:"IconDevice") ?? UIImage()
        iconView.image = image.imageTinted(Styles.colorWhite)
        iconView.contentMode = .scaleAspectFit
        rounded.addSubview(iconView)

        actionLabel.text = "history.button".localized
        actionLabel.font = Styles.defaultFont(size: range(15...35))
        actionLabel.numberOfLines = 1
        actionLabel.textColor = Styles.colorWhite
        rounded.addSubview(actionLabel)

        let superview = rounded

        let marginX = range(20...40)
        let marginButtonX = range(40...250)
        let marginY = marginX
        let spaceY = range(20...40)

        rounded.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 0,
                left: marginX,
                bottom: spaceY,
                right: marginX
            ))
        }

        let imageRatio = image.size.height / image.size.width

        filenameLabel.snp.makeConstraints { make in
            make.top.equalTo(superview).offset(marginY)
            make.left.equalTo(superview).offset(marginX)
            make.right.equalTo(superview).offset(-marginX)
        }

        dateLabel.snp.makeConstraints { make in
            make.left.right.equalTo(filenameLabel)
            make.top.equalTo(filenameLabel.snp.bottom).offset(spaceY)
        }

        lineView.snp.makeConstraints { make in
            make.left.right.equalTo(filenameLabel)
            make.height.equalTo(1)
            make.top.equalTo(dateLabel.snp.bottom).offset(spaceY)
        }

        iconView.snp.makeConstraints { make in
            make.left.equalTo(marginButtonX)
            make.top.equalTo(lineView.snp.bottom).offset(spaceY)
            make.bottom.equalTo(superview).offset(-marginY)
            make.width.equalTo(superview).multipliedBy(0.1)
            make.height.equalTo(iconView.snp.width).multipliedBy(imageRatio)
        }

        actionLabel.snp.makeConstraints { make in
            make.left.equalTo(iconView.snp.right).offset(marginX)
            make.right.equalTo(superview).offset(-marginButtonX)
            make.centerY.equalTo(iconView)
        }
    }

    public var roundedBackgroundColor : UIColor? {
        set(newValue) {
            rounded.backgroundColor = newValue
        }
        get {
            return rounded.backgroundColor
        }
    }
}


final class HistoryViewController: BaseViewController, UITableViewDelegate, UITableViewDataSource {

    private let instructionsView = UIView()
    private let tableView = UITableView()


    private let dateFormatter = DateFormatter()

    private var recent: [HexFile] = []
    private var builtins: [HexFile] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "history.title".localized
        view.backgroundColor = Styles.colorWhite

        let buttonHelp = createHelpButton()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView:buttonHelp)

        setupTable()
        setupInstructions()

        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.dateFormat = "EEEE, dd.MM.yyyy\nHH:mm:ss 'Uhr'"
    }

    func setupInstructions() {

        instructionsView.backgroundColor = Styles.colorWhite.withAlphaComponent(0.95)
        view.addSubview(instructionsView)

        let labelText = UILabel()

        labelText.text = "history.text".localized
        labelText.numberOfLines = 0
        labelText.font = Styles.defaultFont(size: range(15...35))
        labelText.textColor = Styles.colorGray
        instructionsView.addSubview(labelText)

        let marginX = range(20...40)
        let marginY = range(20...40)

        labelText.snp.makeConstraints { make in
            make.top.equalTo(instructionsView).offset(marginY)
            make.left.equalTo(instructionsView).offset(marginX)
            make.right.equalTo(instructionsView).offset(-marginX)
            make.bottom.equalTo(instructionsView).offset(-marginY)
        }

        instructionsView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
    }

    func setupTable() {
        tableView.register(HistoryTableViewCell.classForKeyedArchiver(), forCellReuseIdentifier: "history")
        tableView.separatorInset = .zero
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = range(200...400)
        view.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        do {
            recent = try HexFileManager.stored()
            builtins = try HexFileManager.builtins()
            // FIXME sort
            LOG("history recent:\(recent.count) builtins:\(builtins.count)")
            tableView.reloadData()
        } catch {
            ERR("history failed to load")

            // FIXME show in UI
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.contentInset = UIEdgeInsets.init(top: instructionsView.bounds.size.height, left: 0, bottom: 0, right: 0)
        tableView.contentOffset = CGPoint(x:0, y:-instructionsView.bounds.size.height)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let isBuiltin = section == 1
        let files = isBuiltin ? builtins : recent
        let file = files[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "history", for: indexPath) as! HistoryTableViewCell

        cell.roundedBackgroundColor = isBuiltin
        ? Styles.colorYellow
        : Styles.colorGray

        cell.filenameLabel.text = isBuiltin
        ? file.name.uppercased()
        : file.name.split(separator: "-")[0].uppercased()

        cell.dateLabel.text = isBuiltin
        ? dateFormatter.string(from: file.date)
        : dateFormatter.string(from: file.date)
        //"Sonntag, 12.10.2017\n10:32:22 Uhr"

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        //return (section == 0) ? "recent" : "builtins"
        return nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 0) ? recent.count : builtins.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let section = indexPath.section
        let files = (section == 0) ? recent : builtins
        let file = files[indexPath.row]

        LOG("history selected \(file)")

        if let device = Device.current {

            let vc = UploadViewConroller()
            vc.file = file
            vc.uuid = device.identifier
            vc.buttonPressAction = { state in

                switch(state) {
                case .progress:
                    print("aborted")
                case .success:
                    print("success")
                case .error:
                    print("error")
                }

            }
            let nc = UINavigationController(rootViewController: vc)
            nc.modalTransitionStyle = .coverVertical
            present(nc, animated: true)

        } else {
            LOG("no target device selected")

            let alert = UIAlertController(
                title: "No Device",
                message: "Please connect a device first",
                preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(
                title: "OK",
                style: UIAlertAction.Style.default,
                handler: nil))
            present(alert, animated: true, completion: nil)

//            let vc = ScannerViewController()
//            let nc = UINavigationController(rootViewController: vc)
//            nc.modalTransitionStyle = .coverVertical
//            present(nc, animated: true)

        }
    }

}
