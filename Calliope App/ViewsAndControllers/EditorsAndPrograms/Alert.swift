//
//  Alert.swift
//  Calliope App
//
//  Created by Calliope on 07.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

// This file contains the general alert logic for this app.
// Using .alert() does not allow to consistently replace one alert by another.


struct AlertModifier: ViewModifier {
    @Binding var alert: (any AppAlert)?
    @State var textFieldContent: String = ""

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                // The two seperate if statements are necessary, because otherwise the transition does not trigger
                if alert != nil {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if let alert {
                    CalliopeAlertCard(alert: alert, textFieldContent: $textFieldContent, perform: dismissAfter)
                        .padding(.horizontal, 40)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: alert == nil)
    }

    private func dismissAfter(_ action: () -> Void) {
        let presentedID = alert?.id
        action()
        if alert?.id == presentedID {
            alert = nil
        }
    }
}

private struct CalliopeAlertCard: View {
    let alert: any AppAlert
    @Binding var textFieldContent: String
    let perform: (() -> Void) -> Void
    @FocusState private var textFieldFocused: Bool

    private var textFieldAlert: (any TextFieldAppAlert)? {
        alert as? any TextFieldAppAlert
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(alert.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let message = alert.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let textFieldAlert {
                    TextField(textFieldAlert.textFieldHint, text: $textFieldContent)
                        .focused($textFieldFocused)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemFill))
                        )
                        .padding(.top, 4)
                }
            }
            .padding(20)

            Divider()

            buttonArea
        }
        .frame(width: 270)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .shadow(radius: 10)
        .task(id: alert.id) {
            textFieldContent = textFieldAlert?.textFieldDefault ?? ""
            textFieldFocused = textFieldAlert != nil
        }
    }

    @ViewBuilder
    private var buttonArea: some View {
        if let textFieldAlert {
            actionList(textFieldAlert.textActions) { action in
                perform {
                    textFieldAlert.textActions.forEach { $0.updateText(text: textFieldContent) }
                    action.execute()
                }
            }
        } else {
            actionList(alert.actions) { action in
                perform {
                    action.execute()
                }
            }
        }
    }

    @ViewBuilder
    private func actionList<Action: AlertActionType>(
        _ actions: [Action],
        onSelect: @escaping (Action) -> Void
    ) -> some View {
        if actions.count <= 2 {
            HStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    if index > 0 {
                        Divider()
                    }
                    alertButton(action, onSelect: onSelect)
                }
            }
            // `Divider()` fills the height of its containing HStack by design; without this,
            // it greedily expands the whole row to whatever height the parent proposes.
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    if index > 0 {
                        Divider()
                    }
                    alertButton(action, onSelect: onSelect)
                }
            }
        }
    }

    private func alertButton<Action: AlertActionType>(
        _ action: Action,
        onSelect: @escaping (Action) -> Void
    ) -> some View {
        Button {
            onSelect(action)
        } label: {
            Text(action.title)
                .font(action.role == nil ? .body.weight(.semibold) : .body)
                .foregroundColor(color(for: action.role))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func color(for role: ButtonRole?) -> Color {
        switch role {
        case .destructive:
            return .calliopeRed
        case .cancel:
            return .secondary
        default:
            return Color("calliope-lilablau")
        }
    }
}

protocol AppAlert: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var message: String? { get }
    var actions: [StandardAlertAction] { get }
}

protocol TextFieldAppAlert: AppAlert {
    var textFieldHint: String { get }
    var textFieldDefault: String? { get }
    var textActions: [TextFieldAlertAction] { get }
}

protocol AlertActionType: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var role: ButtonRole? { get }

    func execute()
}

struct StandardAlertAction: AlertActionType {
    let id = UUID()
    let title: String
    let role: ButtonRole?
    let handler: () -> Void  // Input is Void

    init(_ title: String, role: ButtonRole? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.handler = handler
    }

    func execute() { handler() }
}

class TextFieldAlertAction: AlertActionType {
    let id = UUID()
    let title: String
    let role: ButtonRole?
    let handler: (String) -> Void
    var text: String?

    init(_ title: String, role: ButtonRole? = nil, handler: @escaping (String) -> Void) {
        self.title = title
        self.role = role
        self.handler = handler
    }

    func updateText(text: String) {
        self.text = text
    }

    func execute() {
        guard let text = self.text else {
            LogNotify.error("Text not set. This is not supposed to happen.")
            return
        }
        handler(text)
    }
}

extension View {
    func appAlerts(
        _ alert: Binding<(any AppAlert)?>
    ) -> some View {
        modifier(AlertModifier(alert: alert))
    }
}

struct ArcadeUSBRequiredAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Arcade-Datei", comment: "")
    let message: String? = NSLocalizedString(
        "Arcade-Dateien können nur per USB-Kabel übertragen werden. Bitte verbinde deinen Calliope mini per USB oder sichere die Datei für später.",
        comment: ""
    )
    let actions: [StandardAlertAction]

    init(saved: @escaping () -> Void, closed: @escaping () -> Void) {
        actions = [
            StandardAlertAction(NSLocalizedString("Sichern", comment: ""), handler: saved),
            StandardAlertAction(NSLocalizedString("Schließen", comment: ""), role: .cancel, handler: closed),
        ]
    }
}

struct ArcadeTransferAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Arcade-Datei", comment: "")
    let message: String? = NSLocalizedString("Möchtest du die Arcade-Datei auf deinen Calliope mini übertragen oder sichern?", comment: "")
    let actions: [StandardAlertAction]

    init(saved: @escaping () -> Void, transfer: @escaping () -> Void, closed: @escaping () -> Void) {
        actions = [
            StandardAlertAction(NSLocalizedString("Sichern", comment: ""), handler: saved),
            StandardAlertAction(NSLocalizedString("Übertragen (USB)", comment: ""), handler: transfer),
            StandardAlertAction(NSLocalizedString("Schließen", comment: ""), role: .cancel, handler: closed),
        ]
    }
}

struct StandardHexUIAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Datei geöffnet", comment: "")
    let message: String? = NSLocalizedString("Möchtest du die Datei sichern oder auf deinen Calliope mini übertragen?", comment: "")
    let actions: [StandardAlertAction]

    init(saved: @escaping () -> Void, transfer: @escaping () -> Void, closed: @escaping () -> Void) {
        actions = [
            StandardAlertAction(NSLocalizedString("Sichern", comment: ""), handler: saved),
            StandardAlertAction(NSLocalizedString("Übertragen", comment: ""), handler: transfer),
            StandardAlertAction(NSLocalizedString("Schließen", comment: ""), role: .cancel, handler: closed),
        ]
    }
}

struct SaveFileWithNameAlert: TextFieldAppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Save Program", comment: "")
    let message: String? = NSLocalizedString("Please choose a name", comment: "")
    let textActions: [TextFieldAlertAction]
    let actions: [StandardAlertAction] = []
    let textFieldHint: String = "Program Name"
    let textFieldDefault: String?

    init(save: @escaping (_ text: String) -> Void, dontSave: @escaping (_ text: String) -> Void, defaultName: String) {
        textActions = [
            TextFieldAlertAction(NSLocalizedString("Save Program", comment: ""), handler: save),
            TextFieldAlertAction(NSLocalizedString("Don't save", comment: ""), handler: dontSave),
        ]
        textFieldDefault = defaultName
    }
}

struct WaitForProgramDownloadAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Wait a little", comment: "")
    let message: String? = NSLocalizedString("The program is being downloaded. Please wait a little.", comment: "")
    let actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
}

struct ProgramDownloadSuccessAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Download finished", comment: "")
    let message: String? = NSLocalizedString("The program is downloaded. Do you want to upload it now?", comment: "")
    let actions: [StandardAlertAction]

    init(upload: @escaping () -> Void) {
        self.actions = [
            StandardAlertAction(NSLocalizedString("Yes", comment: ""), handler: upload),
            StandardAlertAction(NSLocalizedString("No", comment: ""), handler: {}),
        ]
    }

}

struct ProgramDownloadFailedAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Program download failed", comment: "")
    let message: String?
    let actions: [StandardAlertAction]

    init(error: String?, completion: @escaping () -> Void) {
        let reason = error ?? NSLocalizedString("The downloaded program is empty", comment: "")
        message = String(format: NSLocalizedString("The program is not ready. The reason is: %@", comment: ""), reason)
        actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: completion)]
    }
}

struct UploadConfirmationAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Upload?", comment: "")
    let message: String?
    let actions: [StandardAlertAction]

    init(name: String?, upload: @escaping () -> Void) {
        let defaultName = NSLocalizedString("the program", comment: "")
        message = String(format: NSLocalizedString("Do you want to upload %@ to your Calliope mini?", comment: ""), name ?? defaultName)
        actions = [
            StandardAlertAction(NSLocalizedString("Upload", comment: ""), handler: upload),
            StandardAlertAction(NSLocalizedString("Cancel", comment: ""), handler: {}),
        ]
    }
}

struct UploadFailedAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Upload failed", comment: "")
    let message: String? = NSLocalizedString(
        "The program does not seem to match the version of your Calliope mini. Please check the hardware selection in your editor again.",
        comment: ""
    )
    let actions: [StandardAlertAction]

    init(goToInformation: @escaping () -> Void) {
        actions = [
            StandardAlertAction(NSLocalizedString("Futher Information", comment: ""), handler: goToInformation),
            StandardAlertAction(NSLocalizedString("Cancel", comment: ""), handler: {}),
        ]
    }
}

struct CannotUploadAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Cannot upload", comment: "Übertragung nicht möglich")
    let message: String? = NSLocalizedString(
        "There is no connected Calliope mini in DFU mode",
        comment: "Es konnte kein Calliope mini gefunden werden"
    )
    let actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
}

struct ArcadeUsbRequiredAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("USB-Verbindung erforderlich", comment: "USB connection required")
    let message: String? = NSLocalizedString(
        "Arcade-Programme können nur per USB auf den Calliope mini übertragen werden.\n\nBitte verbinde den Calliope mini per USB-Kabel und wähle den MINI-Ordner aus.",
        comment: "Arcade programs can only be transferred via USB"
    )
    let actions: [StandardAlertAction]

    init(onOpenUsbMode: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.actions = [
            StandardAlertAction(
                NSLocalizedString("USB-Modus öffnen", comment: "Open USB mode"),
                handler: onOpenUsbMode
            ),
            StandardAlertAction(
                NSLocalizedString("Abbrechen", comment: "Cancel"),
                role: .cancel,
                handler: onCancel
            ),
        ]
    }
}

struct OkAppAlert: AppAlert {
    let id = UUID()
    let title: String
    let message: String?
    let actions: [StandardAlertAction]

    init(title: String, message: String? = nil, completion: @escaping () -> Void) {
        self.title = title
        self.message = message
        actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: completion)]
    }
}

struct WebViewNavigationErrorAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Navigation Failed", comment: "")
    let message: String?
    let actions: [StandardAlertAction]

    init(error: Error) {
        message = error.localizedDescription
        actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
    }
}

struct GenericAlert: AppAlert {
    let id = UUID()
    let title: String
    let message: String?
    let actions: [StandardAlertAction]

    init(title: String, message: String? = nil, actions: [StandardAlertAction]) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}

struct GenericTextFieldAlert: TextFieldAppAlert {
    let id = UUID()
    let title: String
    let message: String?
    let textActions: [TextFieldAlertAction]
    let actions: [StandardAlertAction] = []
    let textFieldHint: String = "Program Name"
    let textFieldDefault: String?

    init(title: String, message: String? = nil, actions: [TextFieldAlertAction], defaultName: String) {
        self.title = title
        self.message = message
        textActions = actions
        textFieldDefault = defaultName
    }
}

struct RenameProgramAlert: TextFieldAppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Enter the new program title", comment: "")
    let message: String? = nil
    let textActions: [TextFieldAlertAction]
    let actions: [StandardAlertAction] = []
    let textFieldHint: String = "Program Name"
    let textFieldDefault: String?

    init(defaultName: String, onRename: @escaping (_ text: String) -> Void) {
        textActions = [
            TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: onRename),
            TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
        ]
        textFieldDefault = defaultName
    }
}

struct DeleteProgramAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Delete?", comment: "")
    let message: String?
    let actions: [StandardAlertAction]

    init(program: HexFile, onDelete: @escaping () -> Void) {
        message = String(format: NSLocalizedString("Do you want to delete %@?", comment: ""), program.name)
        actions = [
            StandardAlertAction(NSLocalizedString("Delete", comment: ""), role: .destructive, handler: onDelete),
            StandardAlertAction(NSLocalizedString("Cancel", comment: ""), role: .cancel, handler: {}),
        ]
    }
}

struct DeleteProgramFailedAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Delete failed", comment: "")
    let message: String?
    let actions: [StandardAlertAction]

    init(program: HexFile, error: Error) {
        message = String(format: NSLocalizedString("Could not delete %@\n", comment: ""), program.name) + error.localizedDescription
        actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
    }
}

struct RenameFailedAlert: AppAlert {
    let id = UUID()
    let title: String
    let message: String?
    let actions: [StandardAlertAction]

    init(oldName: String, newName: String) {
        self.title = String(format: NSLocalizedString("Could not rename %@", comment: ""), oldName)
        self.message = String(
            format: NSLocalizedString("The name %@ could not be given to %@. The name for a program must be unique and not empty.", comment: ""),
            newName,
            oldName
        )
        actions = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
    }
}

protocol Alertable: AnyObject {
    var alert: (any AppAlert)? { get set }
}

extension Alertable {
    func setAlert(_ newAlert: (any AppAlert)?) {
        alert = newAlert
    }
}

struct RenameProjectAlert: TextFieldAppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Change project name", comment: "")
    let message: String? = NSLocalizedString("Enter the new project name", comment: "")
    let textActions: [TextFieldAlertAction]
    let actions: [StandardAlertAction] = []
    let textFieldHint: String = NSLocalizedString("New project", comment: "")
    let textFieldDefault: String?

    init(defaultName: String, onRename: @escaping (_ text: String) -> Void) {
        textActions = [
            TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: onRename),
            TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
        ]
        textFieldDefault = defaultName
    }
}

struct DeleteProjectAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Delete?", comment: "")
    let message: String?
    let actions: [StandardAlertAction]

    init(project: Project, onDelete: @escaping () -> Void) {
        message = String(format: NSLocalizedString("Do you want to delete %@?", comment: ""), project.name)
        actions = [
            StandardAlertAction(NSLocalizedString("Delete", comment: ""), role: .destructive, handler: onDelete),
            StandardAlertAction(NSLocalizedString("Cancel", comment: ""), role: .cancel, handler: {}),
        ]
    }
}

struct ExportCSVNameAlert: TextFieldAppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Export Data", comment: "")
    let message: String? = NSLocalizedString("Enter the CSV file name", comment: "")
    let textActions: [TextFieldAlertAction]
    let actions: [StandardAlertAction] = []
    let textFieldHint: String = "CSV_Export"
    let textFieldDefault: String?

    init(onOk: @escaping (_ text: String) -> Void) {
        textActions = [
            TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: { text in
                onOk(text.isEmpty ? "CSV_Export" : text)
            }),
            TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
        ]
        textFieldDefault = nil
    }
}

struct ConnectCalliopeRequiredAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Calliope mini verbinden!", comment: "")
    let message: String? = NSLocalizedString("Verbindung notwendig, um Daten anzeigen zu lassen.", comment: "")
    let actions: [StandardAlertAction] = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
}

struct WrongStorageLocationAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Wrong storage location", comment: "")
    let message: String? = NSLocalizedString("You have not selected a Calliope folder as storage location", comment: "")
    let actions: [StandardAlertAction] = [StandardAlertAction(NSLocalizedString("OK", comment: ""), handler: {})]
}

struct BluetoothDeactivatedAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Bluetooth deactivated", comment: "Bluetooth is turned off")
    let message: String? = NSLocalizedString("Bluetooth must be activated to send data to Calliope mini!", comment: "Bluetooth required message")
    let actions: [StandardAlertAction]

    init(openSettings: @escaping () -> Void, ok: @escaping () -> Void) {
        actions = [
            StandardAlertAction(NSLocalizedString("Open Settings", comment: "Open Settings button"), handler: openSettings),
            StandardAlertAction("OK", role: .cancel, handler: ok),
        ]
    }
}

struct BluetoothResetRequiredAlert: AppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Bluetooth-Verbindung zurücksetzen", comment: "Reset Bluetooth connection")
    let message: String? = NSLocalizedString(
        "Der Calliope mini wurde schon einmal gekoppelt. Diese Informationen müssen erneut angelegt werden:\n\n1. Gehe zu Einstellungen → Bluetooth\n2. Tippe auf das (i) neben dem Calliope mini\n3. Wähle \"Dieses Gerät ignorieren\"\n4. Kehre zur Calliope mini App zurück und verbinde erneut",
        comment: "Instructions to reset Bluetooth pairing"
    )
    let actions: [StandardAlertAction]

    init(openSettings: @escaping () -> Void) {
        actions = [
            StandardAlertAction(NSLocalizedString("Einstellungen öffnen", comment: "Open Settings"), handler: openSettings),
            StandardAlertAction("OK", role: .cancel, handler: {}),
        ]
    }
}

struct NewProjectNameAlert: TextFieldAppAlert {
    let id = UUID()
    let title: String = NSLocalizedString("Enter an Projectname for the new Project", comment: "")
    let message: String? = nil
    let textActions: [TextFieldAlertAction]
    let actions: [StandardAlertAction] = []
    let textFieldHint: String = "Calliope Project"
    let textFieldDefault: String?

    init(onCreate: @escaping (_ text: String) -> Void) {
        textActions = [
            TextFieldAlertAction(NSLocalizedString("OK", comment: ""), handler: { text in
                onCreate(text.isEmpty ? "Calliope Project" : text)
            }),
            TextFieldAlertAction(NSLocalizedString("Cancel", comment: ""), handler: { _ in }),
        ]
        textFieldDefault = nil
    }
}

class TestAlertable: Alertable {
    var alert: (any AppAlert)? {
        didSet {
            LogNotify.error("Tried to show alert, but only the TestAlertable was initialized. This should not happen.")
        }
    }
}

protocol CanShowProgess: AnyObject {
    var progress: (any ProgressAlert)? { get set }
}

protocol ProgressAlert {

}

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
        AlertGalleryEntry(name: "ArcadeUsbRequiredAlert", alert: ArcadeUsbRequiredAlert(onOpenUsbMode: {}, onCancel: {})),
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
