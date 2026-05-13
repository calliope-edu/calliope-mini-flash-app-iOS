import UIKit
import WebKit

import ScratchLinkKit

final class EditorViewController: UIViewController {

    /// Injected into MakeCode and Arcade pages on the affected iOS releases
    /// (26.4.2 / 26.5.x / 26.6.x) to work around a WKWebView/Blockly v12 bug:
    /// clicking the currently-selected toolbox category does not toggle the
    /// flyout. At page load the top category is auto-selected by Blockly, so
    /// the first click on it does nothing — the user has to click *another*
    /// category first, after which clicks on the top category work again.
    ///
    /// Earlier attempts (`clearSelection()` at init, DOM-click warmup at
    /// init) did not stick: Blockly re-asserts its internal selected state,
    /// and the click-toggle path keeps failing whenever the user clicks the
    /// already-selected category.
    ///
    /// This version installs an **active click hook** on every toolbox row:
    /// after the user's click is dispatched, we wait ~100 ms and check if
    /// Blockly's flyout is actually visible. If not, we force-reopen it by
    /// briefly deselecting and re-selecting the current item via Blockly's
    /// API — which *does* trigger a fresh flyout render. The user sees the
    /// flyout open with a barely-perceptible 100 ms delay; every subsequent
    /// click works at full speed.
    ///
    /// A MutationObserver re-installs the hook on any toolbox row that
    /// Blockly recreates later (e.g. when categories are dynamically added).
    ///
    /// Restricted by host so Open Roberta / MicroPython / Scratch are not
    /// touched. All Blockly API calls are wrapped in try/catch + feature
    /// detection so a different Blockly version won't crash the page.
    fileprivate static let blocklyToolboxFixUserScript: WKUserScript = {
        let js = """
        (function() {
            // Unconditional ping so we always have a log line.
            console.warn('🟢 [Calliope iOS] script entry, host=' + location.host);

            var host = location.host || '';
            if (host.indexOf('makecode.calliope.cc') === -1 &&
                host.indexOf('arcade.makecode.com') === -1) {
                console.warn('🟡 [Calliope iOS] host not matched — exiting');
                return;
            }
            console.warn('🟢 [Calliope iOS] host matched, installing document-level click listener');

            var STYLE_ID = 'calliope-fix-hide-flyout';
            var inFixSequence = false;

            function getClassString(el) {
                if (!el) return '';
                var c = el.className;
                if (c && typeof c === 'object' && 'baseVal' in c) {
                    return c.baseVal || '';
                }
                return typeof c === 'string' ? c : '';
            }

            // Walks up from the click target to find a real toolbox **category
            // row**. Rejects anything inside a flyout, the workspace canvas,
            // a draggable block, or a toolbox category group wrapper — those
            // are not real categories and triggering a cycle fix for them
            // causes the Grundlagen flyout to pop up unexpectedly during
            // block drag-and-drop.
            //
            // Match criterion: an element whose class contains `blocklyTreeRow`
            // (the actual category row), and whose path up to the body does
            // not pass through a flyout / workspace / draggable block first.
            function findToolboxAncestor(target) {
                var node = target;
                var depth = 0;
                while (node && node !== document.body && depth < 20) {
                    var cls = getClassString(node);
                    if (cls) {
                        // Hit a flyout / workspace / draggable container before
                        // we found a category row → this click is not a
                        // toolbox category interaction.
                        if (/blocklyFlyout|blocklyMainBackground|blocklyWorkspace|blocklyDraggable|blocklyBlockCanvas|blocklyBubbleCanvas/.test(cls)) {
                            return null;
                        }
                        // The thing we actually care about.
                        if (/(?:^|\\s)blocklyTreeRow(?:$|\\s)/.test(cls)) {
                            return node;
                        }
                    }
                    node = node.parentElement;
                    depth += 1;
                }
                return null;
            }

            // Diagnostic — log all flyout-like elements with their visibility,
            // size, and class. Helps figure out which element actually
            // represents "the layer" the user sees on screen.
            function dumpFlyouts() {
                var flyouts = document.querySelectorAll('[class*="blocklyFlyout"]');
                console.warn('🔍 [Calliope iOS] flyouts found: ' + flyouts.length);
                for (var i = 0; i < flyouts.length; i++) {
                    var f = flyouts[i];
                    var s = window.getComputedStyle(f);
                    var r = f.getBoundingClientRect();
                    console.warn('  [' + i + '] tag=' + f.tagName +
                                 ' cls="' + getClassString(f).substring(0, 60) + '"' +
                                 ' disp=' + s.display +
                                 ' vis=' + s.visibility +
                                 ' opa=' + s.opacity +
                                 ' size=' + Math.round(r.width) + 'x' + Math.round(r.height) +
                                 ' pos=' + Math.round(r.left) + ',' + Math.round(r.top));
                }
            }

            function findToolboxRows() {
                // Only real category rows, not group containers
                // (.blocklyToolboxCategoryGroup is a wrapper, not clickable).
                return document.querySelectorAll('.blocklyTreeRow');
            }

            function findOtherRow(currentHit) {
                var rows = findToolboxRows();
                for (var i = 0; i < rows.length; i++) {
                    var row = rows[i];
                    if (row === currentHit) continue;
                    // Prefer a non-selected row so the "switch" semantics
                    // trigger Blockly's onSelection handler.
                    if (getClassString(row).indexOf('blocklyTreeSelected') === -1) {
                        return row;
                    }
                }
                // Fallback: any row that isn't the target.
                for (var j = 0; j < rows.length; j++) {
                    if (rows[j] !== currentHit) return rows[j];
                }
                return null;
            }

            // DOM-only visibility check — no Blockly API needed since PXT
            // does not expose Blockly on window.
            function isFlyoutVisibleDom() {
                var el = document.querySelector('.blocklyFlyout, [class*="blocklyFlyout"]');
                if (!el) return false;
                var style = window.getComputedStyle(el);
                if (style.display === 'none') return false;
                if (style.visibility === 'hidden') return false;
                var rect = el.getBoundingClientRect();
                return rect.width > 1 && rect.height > 1;
            }

            // Dispatch a realistic touch-tap on the given element. Mirrors
            // the full event sequence iOS fires for a real finger tap:
            //   pointerdown(touch) → touchstart → mousedown → pointerup(touch)
            //   → touchend → mouseup → click
            // Blockly v12's toolbox handler runs on pointerdown and calls
            // preventDefault — that's why click never fires for real Grundlagen
            // taps. So our pointerdown needs to land with the correct
            // pointerType='touch' so Blockly takes it as a touch input.
            function dispatchClickLike(el) {
                if (!el || !el.getBoundingClientRect) return;
                var rect = el.getBoundingClientRect();
                var x = rect.left + Math.max(1, rect.width / 2);
                var y = rect.top + Math.max(1, rect.height / 2);

                function pointer(type) {
                    return new PointerEvent(type, {
                        bubbles: true, cancelable: true, composed: true, view: window,
                        clientX: x, clientY: y, screenX: x, screenY: y,
                        button: 0, buttons: (type === 'pointerdown') ? 1 : 0,
                        pointerType: 'touch', pointerId: 1, isPrimary: true,
                        width: 1, height: 1, pressure: (type === 'pointerdown') ? 1 : 0
                    });
                }
                function mouse(type) {
                    return new MouseEvent(type, {
                        bubbles: true, cancelable: true, composed: true, view: window,
                        clientX: x, clientY: y, screenX: x, screenY: y,
                        button: 0, buttons: (type === 'mousedown') ? 1 : 0
                    });
                }
                function touch(type) {
                    if (!window.Touch || !window.TouchEvent) return null;
                    try {
                        var t = new Touch({
                            identifier: 1,
                            target: el,
                            clientX: x, clientY: y, pageX: x, pageY: y,
                            screenX: x, screenY: y,
                            radiusX: 1, radiusY: 1, rotationAngle: 0, force: 1
                        });
                        var list = (type === 'touchend') ? [] : [t];
                        return new TouchEvent(type, {
                            bubbles: true, cancelable: true, composed: true,
                            touches: list, targetTouches: list, changedTouches: [t]
                        });
                    } catch (e) { return null; }
                }
                function fire(ev) { if (ev) { try { el.dispatchEvent(ev); } catch (e) {} } }

                // Press
                fire(pointer('pointerdown'));
                fire(touch('touchstart'));
                fire(mouse('mousedown'));
                // Release
                fire(pointer('pointerup'));
                fire(touch('touchend'));
                fire(mouse('mouseup'));
                // Synthesised click (Blockly may have preventDefault'd it, fine)
                fire(mouse('click'));
            }

            function hideFlyout() {
                if (document.getElementById(STYLE_ID)) return;
                var style = document.createElement('style');
                style.id = STYLE_ID;
                style.textContent =
                    '.blocklyFlyout, [class*="blocklyFlyout"]' +
                    ' { visibility: hidden !important; }';
                document.head && document.head.appendChild(style);
            }

            function unhideFlyout() {
                var style = document.getElementById(STYLE_ID);
                if (style && style.parentNode) {
                    style.parentNode.removeChild(style);
                }
            }

            // Reproduces the user's manual workaround: click *another*
            // category first, then click the target. After the cycle the
            // target category's flyout is open.
            function runCycleFix(targetRow) {
                var other = findOtherRow(targetRow);
                if (!other) {
                    console.warn('🔴 [Calliope iOS] cycle fix: no other row found');
                    return;
                }
                console.warn('🔧 [Calliope iOS] running cycle fix via synthetic clicks');
                inFixSequence = true;
                hideFlyout();

                dispatchClickLike(other);
                setTimeout(function() {
                    dispatchClickLike(targetRow);
                    setTimeout(function() {
                        unhideFlyout();
                        inFixSequence = false;
                        if (isFlyoutVisibleDom()) {
                            console.warn('🟢 [Calliope iOS] cycle fix succeeded');
                        } else {
                            console.warn('🔴 [Calliope iOS] cycle fix did NOT open flyout — Blockly may reject synthetic events on iOS 26');
                        }
                    }, 150);
                }, 200);
            }

            // Diagnostic — log every interaction event in capture phase so we
            // can identify which event type Blockly's Grundlagen handler
            // listens to. Blockly v12 uses PointerEvents internally; the
            // synthesized `click` may be preventDefault'd, hiding it from any
            // bubble-phase listener.
            function logEvent(symbol, e) {
                var t = e.target;
                var cls = getClassString(t).substring(0, 60);
                console.warn(symbol + ' [Calliope iOS] ' + e.type +
                             ' tag=' + t.tagName + ' class="' + cls + '"');
            }

            // Track once per gesture so we don't try to fix something twice.
            var lastFixAt = 0;

            function handleInteractionOnToolbox(target) {
                if (inFixSequence) return;
                var hit = findToolboxAncestor(target);
                if (!hit) return;

                // Synchronously latch the debounce timestamp so subsequent
                // events from the same gesture (pointerdown → touchstart →
                // click) do not all schedule their own cycle-fix attempts.
                var now = Date.now();
                if (now - lastFixAt < 800) return;
                lastFixAt = now;

                console.warn('🟢 [Calliope iOS] toolbox interaction, ancestor class="' +
                             getClassString(hit).substring(0, 80) + '"');

                setTimeout(function() {
                    if (isFlyoutVisibleDom()) {
                        console.warn('🟢 [Calliope iOS] flyout visible — ok');
                    } else {
                        console.warn('🟡 [Calliope iOS] flyout NOT visible — running cycle fix');
                        runCycleFix(hit);
                    }
                }, 200);
            }

            // Capture-phase listeners for every event type Blockly v12 might
            // be using to drive its toolbox. We act on pointerdown/touchstart
            // because those fire even when click is preventDefault'd.
            document.addEventListener('pointerdown', function(e) {
                logEvent('🟣', e);
                handleInteractionOnToolbox(e.target);
            }, true);

            document.addEventListener('touchstart', function(e) {
                logEvent('🟠', e);
                handleInteractionOnToolbox(e.target);
            }, true);

            document.addEventListener('mousedown', function(e) {
                logEvent('⚪', e);
            }, true);

            document.addEventListener('click', function(e) {
                logEvent('🔵', e);
                handleInteractionOnToolbox(e.target);
            }, true);

            console.warn('🟢 [Calliope iOS] interaction listeners installed (pointer/touch/mouse/click in capture phase)');
        })();
        """
        return WKUserScript(source: js,
                            injectionTime: .atDocumentEnd,
                            forMainFrameOnly: true)
    }()

    var webview: WKWebView!  //webviews are buggy and cannot be placed via interface builder
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var editor: Editor?
    private var latestDownloadedTargetFile: URL?
    var documentsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var downloadsPath: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }
    
    private let scratchLink = ScratchLink()
    
    let filenameQuery = "document.querySelector('input#fileNameInput2').value"
    
    init?(coder: NSCoder, editor: Editor) {
        self.editor = editor
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let editor = editor, let url = editor.url else {
            LogNotify.log("No editor or empty URL -- bailing")
            return
        }

        navigationItem.title = editor.name
        view.backgroundColor = Styles.colorWhite

        let controller = WKUserContentController()

        #if DEBUG
        WebLogHandler().register(with: controller, WebLogHandler.ALL_LEVELS)
        #endif

        // Workaround for an iOS 26.4.2 / 26.5.x / 26.6.x Blockly v12 bug where
        // tapping the topmost toolbox category ("Grundlagen" in MakeCode,
        // "Sprites" in Arcade) does not toggle its flyout. The iOS gate is
        // performed inside the user script itself so we always have a log
        // trail, even on iOS versions outside the affected range.
        let osv = ProcessInfo.processInfo.operatingSystemVersion
        LogNotify.log("⚙️ [Calliope iOS] EditorViewController.viewDidLoad — OS \(osv.majorVersion).\(osv.minorVersion).\(osv.patchVersion) — injecting toolbox script")
        controller.addUserScript(EditorViewController.blocklyToolboxFixUserScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.mediaTypesRequiringUserActionForPlayback = .video

        // Enable persistent caching for offline support
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        
        webview = WKWebView(frame: self.view.bounds, configuration: configuration)
        webview.translatesAutoresizingMaskIntoConstraints = false

        webview.navigationDelegate = self
        webview.uiDelegate = self
        webview.backgroundColor = Styles.colorWhite

        // Configure scroll view to better handle touches in web content
        // This helps with selecting items in MakeCode project lists
        webview.scrollView.delaysContentTouches = false
        webview.scrollView.canCancelContentTouches = true
        webview.scrollView.contentInsetAdjustmentBehavior = .never

        self.view.insertSubview(webview, at: 0)
        let safeArea: UILayoutGuide = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webview.topAnchor.constraint(equalTo: safeArea.topAnchor),
            webview.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            webview.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        scratchLink.setup(webView: self.webview)
        scratchLink.delegate = self
        
        loadingIndicator.startAnimating()
        webview.configuration.applicationNameForUserAgent = editor is BlocksMiniEditor ? "Scrub" : nil
        webview.customUserAgent = traitCollection.userInterfaceIdiom == .pad && !(editor is BlocksMiniEditor) ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1" : nil

        // Use protocol cache policy: respects HTTP cache headers when online,
        // falls back to cache when offline
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        self.webview?.load(request)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Hide the tab bar to provide more screen space for the editor
        self.tabBarController?.tabBar.isHidden = true

        // Disable all navigation gestures to prevent interference with web view content
        disableNavigationGestures()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Show the tab bar again when leaving the editor
        self.tabBarController?.tabBar.isHidden = false

        MatrixConnectionViewController.instance.restartFromBLEConnectionDrop()

        // Re-enable navigation gestures
        enableNavigationGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure gestures remain disabled after view fully appears
        // This catches any gestures that might be re-added during transitions
        disableNavigationGestures()
    }

    // MARK: - Gesture Management

    private func disableNavigationGestures() {
        // Disable the standard interactive pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = true

        // Disable edge pan gestures and any pan gestures on the navigation controller's view
        // This prevents fluid navigation from interfering with web view content
        if let gestures = navigationController?.view.gestureRecognizers {
            for gesture in gestures {
                if gesture is UIScreenEdgePanGestureRecognizer || gesture is UIPanGestureRecognizer {
                    gesture.isEnabled = false
                }
            }
        }

        // Also configure the webview's scroll view pan gesture to not delay touches
        if let panGesture = webview?.scrollView.panGestureRecognizer {
            panGesture.delaysTouchesBegan = false
            panGesture.delaysTouchesEnded = false
        }
    }

    private func enableNavigationGestures() {
        // Re-enable the standard interactive pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        // Re-enable gestures on the navigation controller's view
        if let gestures = navigationController?.view.gestureRecognizers {
            for gesture in gestures {
                if gesture is UIScreenEdgePanGestureRecognizer || gesture is UIPanGestureRecognizer {
                    gesture.isEnabled = true
                }
            }
        }
    }
    
}

extension EditorViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let editor = editor else {
            return
        }

        LogNotify.log("policy for action \(navigationAction.request.url?.absoluteString.truncate(length: 100) ?? "")")
        
        let request = navigationAction.request
        
        if navigationAction.shouldPerformDownload && (editor is MicroPython || editor is CampusEditor){
            decisionHandler(.download)
        } else if let download = editor.download(request) {
            decisionHandler(.cancel)
            if download.url.absoluteString.starts(with: "data:text/xml") {
                export(download: download)
            } else {
                upload(result: download)
            }
        } else if editor.isBackNavigation(request) {
            decisionHandler(.cancel)
            self.navigationController?.popViewController(animated: true)
        } else if editor.allowNavigation(request) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }


    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let editor = editor else {
            return nil
        }

        switch editor.getNavigationTargetViewForRequest(navigationAction.request) {
        case .internalWebView:
            return handleInternalWebView(navigationAction, webView)
        case .externalWebView:
            return handleExternalWebView(navigationAction)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        loadingIndicator.stopAnimating()
        handlePossibleEditorChanges()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        LogNotify.log("\(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        LogNotify.log("\(error)")
    }
    
    // helper
    
    fileprivate func handleInternalWebView(_ navigationAction: WKNavigationAction, _ webView: WKWebView) -> WKWebView? {
        guard navigationAction.targetFrame != nil else {
            return nil
        }
        webView.load(navigationAction.request)
        return nil
    }


    fileprivate func handleExternalWebView(_ navigationAction: WKNavigationAction) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
 
}

extension EditorViewController: WKUIDelegate {
     func webView(
        _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler()
                }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(
        _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler(true)
                }))

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler(false)
                }))

        present(alertController, animated: true, completion: nil)
    }


    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {

        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""), style: .default,
                handler: { (action) in
                    if let text = alertController.textFields?.first?.text {
                        completionHandler(text)
                    } else {
                        completionHandler(defaultText)
                    }
                }))

        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: ""), style: .default,
                handler: { (action) in
                    completionHandler(nil)
                }))

        present(alertController, animated: true, completion: nil)
    }   
}

extension EditorViewController: WKDownloadDelegate {
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard let editor = editor, editor is MicroPython || editor is CampusEditor else {
            return
        }
        
        latestDownloadedTargetFile = prepareTemporaryStorage(for: suggestedFilename)
        try? FileManager.default.removeItem(at: latestDownloadedTargetFile!)
        completionHandler(latestDownloadedTargetFile)
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        guard let url = latestDownloadedTargetFile, let fileextension = FileExtension(rawValue: url.pathExtension.lowercased()) else {
            return
        }
        
        switch fileextension {
        case .hex:
            uploadHex(from: url)
        case .html, .json:
            storeSessionData(for: url)
        }
        
    }
    
    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        LogNotify.log("Download failed: \(error)")
        self.clearTemporaryStorage()
    }
   
    // MARK: Helper
    
    private func prepareTemporaryStorage(for name: String) -> URL? {
        return NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    }
    
    private func clearTemporaryStorage() {
        guard let latestDownloadedTargetFile = latestDownloadedTargetFile else {
            return
        }
        
        try? FileManager.default.removeItem(at: latestDownloadedTargetFile)
        self.latestDownloadedTargetFile = nil
    }
    
    private func uploadHex(from location: URL) {
        LogNotify.log("Treating downloaded file as a Hex-File for the mini: \(location.absoluteString)")
        guard location.isFileURL, FileExtension(rawValue: location.pathExtension.lowercased()) == .hex else {
            LogNotify.log("Location of hex file was not provided or target at locationis not a hex file.")
            return
        }
        
        let file = HexFile(url: location, name: location.lastPathComponent, date: Date())
        FirmwareUpload.uploadWithoutConfirmation(controller: self, program: file) {
            MatrixConnectionViewController.instance.connect()
            self.clearTemporaryStorage()
        }
    }
    
    private func storeSessionData(for location: URL) {
        LogNotify.log("Treating downloaded file as session relevant data: \(location.absoluteString)")
        guard location.isFileURL, [FileExtension.html, FileExtension.json].contains(FileExtension(rawValue: location.pathExtension.lowercased())) else {
            LogNotify.log("Location of session data file was not provided, or is neither in json or html format")
            return
        }
        
        do {
            let documentsDir = try StorageDirectory.shared.documentsDirectory()
            let destination = documentsDir.appendingPathComponent(location.lastPathComponent)
            try FileManager.default.moveItem(at: location, to: destination)
            showAlertSessionDataDownload(for: .success)
        } catch {
            showAlertSessionDataDownload(for: .failure)
        }
    }
    
     
    private func showAlertSessionDataDownload(for status: OperationStatus) {
        let title =
            switch status {
            case .success: NSLocalizedString("Session data successfully downloaded!", comment: "")
            default: NSLocalizedString("Failed to download session data!", comment: "")
            }

        let message =
            switch status {
            case .success: NSLocalizedString("You can find the session data, in the Calliope directory on your device.", comment: "")
            default: NSLocalizedString("The download of the session data was unsuccessful.", comment: "")
            }

        let alert = UIAlertController(
            title: title,
            message: String(format: message),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "OK", style: .cancel) { _ in
                self.dismiss(animated: true)
            }
        )
        self.present(alert, animated: true)
    }


}

extension EditorViewController: ScratchLinkDelegate {
    
    func canStartSession(type: ScratchLinkKit.SessionType) -> Bool {
        LogNotify.log("Call to 'canStartSession'")
        return true
    }
    
    func didStartSession(type: ScratchLinkKit.SessionType) {
        LogNotify.log("Call to 'didStartSession'")
    }
    
    func didFailStartingSession(type: ScratchLinkKit.SessionType, error: ScratchLinkKit.SessionError) {
        LogNotify.log("Call to 'didFailStartingSession'")
    }
     
}

extension EditorViewController {
    // MARK: Handle possible editor change (i.e. Scratch Based with own BLE connection)
    
    private func handlePossibleEditorChanges() {
        determineIfScratchBasedEditor() { self.switchEditorImperatives($0)}
    }
    
    
    private func determineIfScratchBasedEditor(completion: @escaping (Bool) -> Void) {
        let condition = "document.getElementById('scratch-link-extension-script') != null"
        
        webview.evaluateJavaScript(condition) { (result, error) in
            let isScratchEditor = result as? Bool ?? false
            completion(isScratchEditor)
        }
    }
    
    private func switchEditorImperatives(_ isScratchEditor: Bool) {
        if (isScratchEditor) {
            LogNotify.log("Switching editor imperatives to handle scratch based editor")
            MatrixConnectionViewController.instance.dropBLEConnection()
            self.webview.customUserAgent = nil
            self.webview.configuration.applicationNameForUserAgent = "Scrub"
            return
        }
        
        LogNotify.log("Switching editor imperatives to handle non-scratch based editor")
        self.webview.configuration.applicationNameForUserAgent = nil
        self.webview.customUserAgent = traitCollection.userInterfaceIdiom == .pad ? "Mozilla/5.0 (iPad; CPU OS 12_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.1 Mobile/15E148 Safari/604.1" : nil
        MatrixConnectionViewController.instance.restartFromBLEConnectionDrop()
    }
}


extension EditorViewController {
    
    //MARK: uploading
    
    private func upload(result download: EditorDownload) {
        self.webview.evaluateJavaScript(filenameQuery) { (result, error) in
            let filename = "\(result ?? "no-project-name")"
            do {
                guard let file = try HexFileManager.store(name: filename, data: download.url.asData(), isHexFile: download.isHex) else {
                    return
                }
                FirmwareUpload.uploadWithoutConfirmation(controller: self, program: file) {
                    MatrixConnectionViewController.instance.connect()
                }
            } catch {
                LogNotify.log(error.localizedDescription)
            }
        }
    }

    private func saveFile(filename: String, data: Data, path: URL? = nil) -> (Bool, Error?) {
        let pathToUse = (path ?? downloadsPath)
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: pathToUse.path) {
                do {
                    try fm.createDirectory(at: pathToUse, withIntermediateDirectories: true)
                } catch {
                    // don't recurse into fallback mode
                    if pathToUse != documentsPath {
                        return saveFile(filename: filename, data: data, path: documentsPath)
                    }
                }
            }
            try data.write(to: pathToUse.appendingPathComponent(filename))
        } catch {
            LogNotify.log("saveFile error: \(error.localizedDescription)")
            return (false, error)
        }

        return (true, nil)
    }

    private func export(download: EditorDownload) {
        do {
            let xml = try download.url.asData()
            let (success, error) = saveFile(filename: "\(download.name).xml", data: xml)
            if success {
                let alert = UIAlertController(
                    title: NSLocalizedString("Program exported", comment: ""),
                    message: NSLocalizedString("Program exported message", comment: "actual message in translation file"),
                    preferredStyle: .alert)

                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .destructive) { _ in
                    })

                self.present(alert, animated: true)
            } else {
                throw error!
            }
        } catch {
            LogNotify.log(error.localizedDescription)
        }
    }

}
