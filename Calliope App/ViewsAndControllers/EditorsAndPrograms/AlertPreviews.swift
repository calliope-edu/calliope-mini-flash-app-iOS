//
//  AlertPreviews.swift
//  Calliope App
//
//  Created by Calliope on 07.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

// SwiftUI preview gallery for every AppAlert in the app. No production code lives here.

private struct AlertGalleryEntry: Identifiable {
    let id = UUID()
    let name: String
    let alert: AppAlert
}

private struct AlertGalleryPreview: View {
    let entries: [AlertGalleryEntry]
    @State private var selectedID: AlertGalleryEntry.ID?
    @State private var presentedAlert: AppAlert?

    var body: some View {
        HStack(spacing: 0) {
            List(entries, selection: $selectedID) { entry in
                Text(entry.name)
                    .font(.footnote)
            }
            .listStyle(.plain)
            .frame(width: 240)

            Divider()

            Rectangle()
                .fill(.white)
                .modifier(AlertModifier(alert: $presentedAlert))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            selectedID = entries.first?.id
            presentedAlert = entries.first?.alert
        }
        .onChange(of: selectedID) { newValue in
            presentedAlert = entries.first { $0.id == newValue }?.alert
        }
    }
}

#Preview("Alerts - Master Detail") {
    let previewHexFile = HexFile(url: URL(fileURLWithPath: "/tmp/my_program.hex"), name: "my_program.hex", date: .now)
    let previewError = NSError(
        domain: "Preview",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "The requested page could not be loaded."]
    )

    let entries: [AlertGalleryEntry] = [
        AlertGalleryEntry(name: "arcadeUSBRequired", alert: .arcadeUSBRequired(saved: {}, closed: {})),
        AlertGalleryEntry(name: "arcadeTransfer", alert: .arcadeTransfer(saved: {}, transfer: {}, closed: {})),
        AlertGalleryEntry(name: "standardHexUI", alert: .standardHexUI(saved: {}, transfer: {}, closed: {})),
        AlertGalleryEntry(
            name: "saveFileWithName",
            alert: .saveFileWithName(save: { _ in }, dontSave: { _ in }, defaultName: "my_program")
        ),
        AlertGalleryEntry(name: "waitForProgramDownload", alert: .waitForProgramDownload()),
        AlertGalleryEntry(name: "programDownloadSuccess", alert: .programDownloadSuccess(upload: {})),
        AlertGalleryEntry(
            name: "programDownloadFailed",
            alert: .programDownloadFailed(error: "Connection timed out", completion: {})
        ),
        AlertGalleryEntry(name: "uploadConfirmation", alert: .uploadConfirmation(name: "my_program.hex", upload: {})),
        AlertGalleryEntry(name: "uploadFailed", alert: .uploadFailed(goToInformation: {})),
        AlertGalleryEntry(name: "cannotUpload", alert: .cannotUpload()),
        AlertGalleryEntry(name: "arcadeUsbModeRequired", alert: .arcadeUsbModeRequired(onOpenUsbMode: {}, onCancel: {})),
        AlertGalleryEntry(name: "ok", alert: .ok(title: "Done", message: "Everything worked.", completion: {})),
        AlertGalleryEntry(name: "webViewNavigationError", alert: .webViewNavigationError(error: previewError)),
        AlertGalleryEntry(
            name: "generic (title/message/actions)",
            alert: AppAlert(title: "Generic Alert", message: "This is a generic alert message.", actions: [
                StandardAlertAction("OK", handler: {}),
            ])
        ),
        AlertGalleryEntry(
            name: "generic (text field)",
            alert: AppAlert(
                title: "Generic Text Field",
                message: "Enter something",
                textField: .init(hint: "Program Name", defaultValue: "Default", actions: [
                    TextFieldAlertAction("OK", handler: { _ in }),
                ])
            )
        ),
        AlertGalleryEntry(name: "renameProgram", alert: .renameProgram(defaultName: "my_program", onRename: { _ in })),
        AlertGalleryEntry(name: "deleteProgram", alert: .deleteProgram(program: previewHexFile, onDelete: {})),
        AlertGalleryEntry(
            name: "deleteProgramFailed",
            alert: .deleteProgramFailed(program: previewHexFile, error: previewError)
        ),
        AlertGalleryEntry(name: "renameFailed", alert: .renameFailed(oldName: "old_name", newName: "new/name")),
        AlertGalleryEntry(name: "renameProject", alert: .renameProject(defaultName: "My Project", onRename: { _ in })),
        AlertGalleryEntry(name: "exportCSVName", alert: .exportCSVName(onOk: { _ in })),
        AlertGalleryEntry(name: "connectCalliopeRequired", alert: .connectCalliopeRequired()),
        AlertGalleryEntry(name: "wrongStorageLocation", alert: .wrongStorageLocation()),
        AlertGalleryEntry(name: "bluetoothDeactivated", alert: .bluetoothDeactivated(openSettings: {}, ok: {})),
        AlertGalleryEntry(name: "bluetoothResetRequired", alert: .bluetoothResetRequired(openSettings: {})),
        AlertGalleryEntry(name: "newProjectName", alert: .newProjectName(onCreate: { _ in })),
    ]

    return AlertGalleryPreview(entries: entries)
}
