//
//  Alert+Previews.swift
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
    let alert: any AppAlert
}

private struct AlertGalleryPreview: View {
    let entries: [AlertGalleryEntry]
    @State private var selectedID: AlertGalleryEntry.ID?
    @State private var presentedAlert: (any AppAlert)?

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
    let previewProject = Project(id: 1, name: "My Project")
    let previewError = NSError(
        domain: "Preview",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "The requested page could not be loaded."]
    )

    let entries: [AlertGalleryEntry] = [
        AlertGalleryEntry(name: "ArcadeUSBRequiredAlert", alert: ArcadeUSBRequiredAlert(saved: {}, closed: {})),
        AlertGalleryEntry(name: "ArcadeTransferAlert", alert: ArcadeTransferAlert(saved: {}, transfer: {}, closed: {})),
        AlertGalleryEntry(name: "StandardHexUIAlert", alert: StandardHexUIAlert(saved: {}, transfer: {}, closed: {})),
        AlertGalleryEntry(
            name: "SaveFileWithNameAlert",
            alert: SaveFileWithNameAlert(save: { _ in }, dontSave: { _ in }, defaultName: "my_program")
        ),
        AlertGalleryEntry(name: "WaitForProgramDownloadAlert", alert: WaitForProgramDownloadAlert()),
        AlertGalleryEntry(name: "ProgramDownloadSuccessAlert", alert: ProgramDownloadSuccessAlert(upload: {})),
        AlertGalleryEntry(
            name: "ProgramDownloadFailedAlert",
            alert: ProgramDownloadFailedAlert(error: "Connection timed out", completion: {})
        ),
        AlertGalleryEntry(name: "UploadConfirmationAlert", alert: UploadConfirmationAlert(name: "my_program.hex", upload: {})),
        AlertGalleryEntry(name: "UploadFailedAlert", alert: UploadFailedAlert(goToInformation: {})),
        AlertGalleryEntry(name: "CannotUploadAlert", alert: CannotUploadAlert()),
        AlertGalleryEntry(name: "ArcadeUsbModeRequiredAlert", alert: ArcadeUsbModeRequiredAlert(onOpenUsbMode: {}, onCancel: {})),
        AlertGalleryEntry(name: "OkAppAlert", alert: OkAppAlert(title: "Done", message: "Everything worked.", completion: {})),
        AlertGalleryEntry(name: "WebViewNavigationErrorAlert", alert: WebViewNavigationErrorAlert(error: previewError)),
        AlertGalleryEntry(
            name: "GenericAlert",
            alert: GenericAlert(title: "Generic Alert", message: "This is a generic alert message.", actions: [
                StandardAlertAction("OK", handler: {}),
            ])
        ),
        AlertGalleryEntry(
            name: "GenericTextFieldAlert",
            alert: GenericTextFieldAlert(title: "Generic Text Field", message: "Enter something", actions: [
                TextFieldAlertAction("OK", handler: { _ in }),
            ], defaultName: "Default")
        ),
        AlertGalleryEntry(name: "RenameProgramAlert", alert: RenameProgramAlert(defaultName: "my_program", onRename: { _ in })),
        AlertGalleryEntry(name: "DeleteProgramAlert", alert: DeleteProgramAlert(program: previewHexFile, onDelete: {})),
        AlertGalleryEntry(
            name: "DeleteProgramFailedAlert",
            alert: DeleteProgramFailedAlert(program: previewHexFile, error: previewError)
        ),
        AlertGalleryEntry(name: "RenameFailedAlert", alert: RenameFailedAlert(oldName: "old_name", newName: "new/name")),
        AlertGalleryEntry(name: "RenameProjectAlert", alert: RenameProjectAlert(defaultName: "My Project", onRename: { _ in })),
        AlertGalleryEntry(name: "DeleteProjectAlert", alert: DeleteProjectAlert(project: previewProject, onDelete: {})),
        AlertGalleryEntry(name: "ExportCSVNameAlert", alert: ExportCSVNameAlert(onOk: { _ in })),
        AlertGalleryEntry(name: "ConnectCalliopeRequiredAlert", alert: ConnectCalliopeRequiredAlert()),
        AlertGalleryEntry(name: "WrongStorageLocationAlert", alert: WrongStorageLocationAlert()),
        AlertGalleryEntry(name: "BluetoothDeactivatedAlert", alert: BluetoothDeactivatedAlert(openSettings: {}, ok: {})),
        AlertGalleryEntry(name: "BluetoothResetRequiredAlert", alert: BluetoothResetRequiredAlert(openSettings: {})),
        AlertGalleryEntry(name: "NewProjectNameAlert", alert: NewProjectNameAlert(onCreate: { _ in })),
    ]

    return AlertGalleryPreview(entries: entries)
}
