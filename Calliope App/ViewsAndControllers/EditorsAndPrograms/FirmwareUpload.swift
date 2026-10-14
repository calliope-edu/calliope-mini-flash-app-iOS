//
//  FirmwareUploadViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 15.06.19.
//

import UIKit

// Legacy UIKit alerts; to be replaced by AppAlert cases on UploadViewModel.
enum FirmwareUpload {

    /// Presents an alert without relying on our progress alert being on screen —
    /// in export-picker mode there is none.
    static func presentStandalone(_ alert: UIAlertController) {
        guard let presenter = FirmwareUpload.topMostViewController() else { return }
        DispatchQueue.main.async {
            presenter.present(alert, animated: true)
        }
    }

    /// Walks the active scene's key window to find the top-most presented
    /// view controller, since there is no stored UIKit controller reference
    /// to present from in the SwiftUI-driven flow.
    private static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first
        return keyWindow?.rootViewController?.topMostPresented()
    }

    /// DIAGNOSTICS (Shared-iPad USB investigation): shows what happened during
    /// the last transfer attempt, including DAPLink's verdict, plus an action to
    /// share the full log. Remove together with
    /// `USBCalliope.showTransferDiagnostics` once the cause is understood.
    static func presentTransferDiagnosticsAlert(verdict: String) {
        let excerpt = LogNotify.recentLines(
            matching: ["Export picker", "Editor download", "USB Transfer"], limit: 12)

        let alert = UIAlertController(
            title: NSLocalizedString("Transfer diagnostics", comment: "Diagnostics alert title"),
            message: verdict + "\n\n" + excerpt,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Share log", comment: "Action to share the in-app log"),
            style: .default) { _ in
                FirmwareUpload.presentLogShareSheet()
            })
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))

        guard let presenter = topMostViewController() else { return }
        presenter.present(alert, animated: true)
    }

    /// Failure alert for a USB transfer, with an action to share the recent log.
    ///
    /// A Shared iPad can only be updated through TestFlight, where no console
    /// output exists — so the log has to be reachable from inside the app for a
    /// problem to be reportable at all.
    static func makeUsbTransferFailureAlert(message: String) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("Upload failed!", comment: ""),
            message: message,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Share log", comment: "Action to share the in-app log"),
            style: .default) { _ in
                FirmwareUpload.presentLogShareSheet()
            })
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
        return alert
    }

    /// Offers the buffered log through the normal share sheet.
    private static func presentLogShareSheet() {
        guard let presenter = topMostViewController() else { return }

        let activityController = UIActivityViewController(
            activityItems: [LogNotify.recentLog], applicationActivities: nil)
        // On iPad an activity sheet must have an anchor, otherwise it traps.
        activityController.popoverPresentationController?.sourceView = presenter.view
        activityController.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        activityController.popoverPresentationController?.permittedArrowDirections = []
        presenter.present(activityController, animated: true)
    }

    static func makeHexMismatchAlert(informationLink: String) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("Upload failed", comment: ""),
            message: String(format: NSLocalizedString("The program does not seem to match the version of your Calliope mini. Please check the hardware selection in your editor again.", comment: "")),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("Further Information", comment: ""), style: .default) { _ in
                if let url = URL(string: informationLink) {
                    UIApplication.shared.open(url)
                }
            })
        return alert
    }
}
