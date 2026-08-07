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
        return UIHostingController(coder: coder, rootView: EditorWebViewRepresentable(editor: editor!, alertPublisher: TestAlertable(), uploadFirmware: {_, _, _ in }))
    }
    
    init?(coder: NSCoder, editor: Editor) {
        self.editor = editor
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
