import UIKit

final class UploadViewConroller: ProgressViewController {

    public var uuid: UUID?
    public var file: HexFile?

    private var process: BluetoothUpload?

    override func viewDidLoad() {
        super.viewDidLoad()

        update(animated: false) { m in
            m.heading = "upload.ready.text".localized
            m.text = ""
            m.button = "upload.button.abort".localized
            m.interaction = true
        }
    }

    override func work() {

        guard let uuid = self.uuid else { return }
        guard let file = self.file else { return }

        unowned let me = self

        let bin = file.bin()
        let dat = HexFile.dat(bin)

        LOG("uploader file:\(file.name) bin:\(bin.count) dat:\(dat.count)")

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let upload = BluetoothUpload(bin:bin, dat:dat, uuid:uuid, { state in
            me.update(from: state)
        })
        self.process = upload
        upload.start()
    }

    override func buttonPress(_ state: ProgressViewControllerState) {
        if state == .progress {
            if let upload = self.process {
                upload.stop()
            }
        }
        super.buttonPress(state)
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }


    func update(from state:BluetoothUploadState) {
        switch(state) {
        case .ready:
            update(animated: true, { m in
                m.state = .progress
                m.heading = "upload.ready.text".localized
                m.text = ""
                m.progress = 0
                m.button = "upload.button.abort".localized
                m.interaction = true
            })
        case let .retrieving(uuid):
            LOG("trying to find peripheral \(uuid)")
            update(animated: true, { m in
                m.state = .progress
                m.heading = "upload.retrieving.text".localized
                m.text = ""
                m.progress = 0
                m.button = "upload.button.abort".localized
                m.interaction = true
            })
        case let .missing(uuid):
            LOG("failed to find peripheral \(uuid)")
            update(animated: true, { m in
                m.state = .error
                m.heading = "upload.missing.text".localized
                m.text = ""
                m.progress = 0
                m.button = "upload.button.error".localized
                m.interaction = true
            })
        case let .rebooted(peripheral):
            LOG("rebooted peripheral \(peripheral.identifier)")
            update(animated: true, { m in
                m.state = .progress
                m.heading = "upload.rebooted.text".localized
                m.text = ""
                m.progress = 0
                m.button = "upload.button.abort".localized
                m.interaction = false
            })
        case let .uploading(progress):
            LOG("uploading progress \(progress)")
            update(animated: true, { m in
                m.state = .progress
                m.heading = String(format: "upload.uploading.text".localized, 100*progress)
                m.text = ""
                m.progress = progress
                m.button = "upload.button.abort".localized
                m.interaction = false
            })
        case .success:
            LOG("uploading successful")
            update(animated: true, { m in
                m.state = .success
                m.heading = "upload.success.text".localized
                m.text = ""
                m.progress = 1
                m.button = "upload.button.success".localized
                m.interaction = true
            })
        case let .error(error):
            LOG("uploading failed \(error)")
            update(animated: true, { m in
                m.state = .error
                m.heading = "upload.error.text".localized
                m.text = "Error \(error)"
                m.progress = 0
                m.button = "upload.button.error".localized
                m.interaction = true
            })
        }
    }
}

