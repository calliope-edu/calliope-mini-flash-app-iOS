//
//  SensordataViewModel.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class SensordataViewModel: ObservableObject {
    @Published var projects: [Project] = []
    private var targetUrl: URL?
    @Environment(\.openURL) var openURL

    func loadProjects() {
        projects = Project.fetchProjects()
    }

    init() {
        projects = Project.fetchProjects()
    }

    func deleteProject(id: Int64) {
        Project.deleteProject(id: id)
        // TODO: Delete Groups and Charts
        loadProjects()
    }

    func initializeDataLoggerViewModel(_ coder: NSCoder) -> DataLoggerViewModel? {
        LogNotify.debug("Setting up DataLogger ViewModel")
        let dataLoggerViewModel = DataLoggerViewModel(coder: coder)

        if !MatrixConnectionViewController.instance.isInUsbMode,
            let result = (MatrixConnectionViewController.instance.usageReadyCalliope as? CalliopeAPI)?.currentJob?.result, dataLoggerViewModel != nil
        {
            dataLoggerViewModel!.htmlData = result
            return dataLoggerViewModel
        }

        if MatrixConnectionViewController.instance.isInUsbMode, let url = targetUrl, dataLoggerViewModel != nil {
            dataLoggerViewModel!.htmlData = try! url.asData()
            return dataLoggerViewModel
        }

        LogNotify.error("No data")
        return nil
    }

    func openBluetoothExtensionPage() {
        if let url = URL(string: "https://calliope.cc/programmieren/mobil/ipad#sensordaten") {
            openURL(url)
        }
    }

    func initializeEditorView(_ coder: NSCoder) -> EditorViewController? {
        var editor = MakeCode()
        editor.url = targetUrl
        return EditorViewController(coder: coder, editor: editor)
    }

    func initializeBluetoothSensorInfoWebView() {
        self.targetUrl = URL.init(string: "https://makecode.calliope.cc/#pub:_30A13o6dM9L2")
        // self.performSegue(withIdentifier: "showEditor", sender: self)
    }

    func initializeDataLoggerInfoWebView() {
        self.targetUrl = URL.init(string: "https://makecode.calliope.cc/#pub:_Dv9J1xCp6HRy")
        // self.performSegue(withIdentifier: "showEditor", sender: self)
    }

    func createNewProject(_ coder: NSCoder) {
        LogNotify.log("Starting to create a new Project")
        /*let alertController = UIAlertController(
            title: NSLocalizedString("Enter an Projectname for the new Project", comment: ""),
            message: nil,
            preferredStyle: .alert
        )
        alertController.addTextField { (textField) in
            textField.placeholder = "Calliope Project"
        }

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let name = textField.text {
                let normalizedName = name.isEmpty ? "Calliope Project" : name
                let project = Project.insertProject(name: normalizedName)
                self.performSegue(withIdentifier: "showNewlyCreatedProject", sender: project?.id)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)*/
    }

    func openLinkToCalliopeInformation() {
        if let url = URL(string: NSLocalizedString("https://calliope.cc/programmieren/mobil/ipad#sensordaten", comment: "")) {
            // UIApplication.shared.open(url)
        }
    }

    func getDataloggerHtml() {
        /*guard let connectedCalliope = self.connectedCalliope else {
            LogNotify.log("Datalogger Data button pressed, while no connected Calliope. This should not happen.")
            return
        }

        if isUsbMode {
            getDataLoggerHTMLFrom(usbCalliope: connectedCalliope)
            return
        }
        getDataLoggerHTMLFrom(bleCalliope: connectedCalliope)*/

    }

    func getDataLoggerHTMLFrom(usbCalliope calliope: Calliope) {
        DispatchQueue.main.async {
            /*let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "htm")!])
            documentPickerController.delegate = self
            self.present(documentPickerController, animated: true, completion: nil)*/
        }
    }

    private func getDataLoggerHTMLFrom(bleCalliope calliope: Calliope) {
        guard let calliope = (calliope as? CalliopeAPI) else {
            return
        }

        /*progressRing.resetProgress()
        self.present(alertView, animated: true)
        calliope.startUtilityJob(
            for: .LOG_HTML,
            onProgress: { [self] (a) in progressRing.startProgress(to: CGFloat(a), duration: 0.2) },
            onCompletion: {
                self.dismiss(animated: true)
                self.performSegue(withIdentifier: "showDataLoggerHTML", sender: self)
            },
            onFailure: {
                self.dismiss(animated: true)

                let failureReason = calliope.currentJob?.jobState
                if failureReason == .Canceled {
                    return
                }

                let alert = UIAlertController(
                    title: NSLocalizedString("Datalogger Download Failed!", comment: ""),
                    message: String(
                        format: NSLocalizedString(
                            "There was an issue downloading the datalogger data from your Calliope mini. Please ensure you are connected to the Calliope and try again.",
                            comment: ""
                        )
                    ),
                    preferredStyle: .alert
                )
                alert.addAction(
                    UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                        self.dismiss(animated: true)
                    }
                )
                self.present(alert, animated: true)
            }
        )*/
    }

}

class PreviewSensordataViewModel: SensordataViewModel {
    override init() {
        super.init()
        projects = [Project(id: 1, name: "Test 1"), Project(id: 2, name: "Test 2"), Project(id: 3, name: "This is a long test name")]
    }
}
