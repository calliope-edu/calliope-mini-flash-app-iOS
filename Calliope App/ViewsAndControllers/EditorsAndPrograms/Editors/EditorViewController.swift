import UIKit
import WebKit
import SwiftUI

import ScratchLinkKit

final class EditorViewController: UIViewController {
    var editor: Editor?
    
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        guard editor != nil else {
            LogNotify.error("Editor is nil. This should not happen.")
            return nil
        }
        return UIHostingController(coder: coder, rootView: EditorWebViewRepresentable(editor: editor!, present: presentAlert, uploadFirmware: uploadFirmware))
    }
    
    init?(coder: NSCoder, editor: Editor) {
        self.editor = editor
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func presentAlert(_ view: UIViewController, _ animated: Bool) {
        present(view, animated: animated)
    }
    
    func uploadFirmware(_ program: HexFile, _ completion: (() -> Void)?) {
        FirmwareUpload.uploadWithoutConfirmation(controller: self, program: program, completion: completion)
    }
}
