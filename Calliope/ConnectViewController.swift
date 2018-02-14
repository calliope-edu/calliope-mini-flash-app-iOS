import UIKit

final class ConnectViewConroller: ProgressViewController {

    public var device: Device? = nil

    private var process: BluetoothPair?

    override func viewDidLoad() {
        super.viewDidLoad()

        update(animated: false) { m in
            m.heading = "connect.ready.heading".localized
            m.text = "connect.ready.text".localized
            m.button = "connect.button.abort".localized
            m.interaction = true
        }
    }

    override func work() {
        unowned let me = self

        guard let device = device else { return }

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let process = BluetoothPair(identifier: device.identifier, { error, _, _ in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false

            if let error = error {
                ERR("failed to connect to \(device): \(error)")

                me.update(animated: true, { m in
                    m.state = .error
                    m.heading = "connect.error.heading".localized
                    m.text = "\(error)"
                    m.button = "connect.button.error".localized
                    m.interaction = true
                })

            } else {
                ERR("switched to \(device)")

                me.update(animated: true, { m in
                    m.state = .success
                    m.heading = "connect.success.heading".localized
                    m.text = "connect.success.text".localized
                    m.button = "connect.button.success".localized
                    m.interaction = true
                })
            }
        })
        self.process = process
    }

    override func buttonPress(_ state: ProgressViewControllerState) {
        super.buttonPress(state)
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

}
