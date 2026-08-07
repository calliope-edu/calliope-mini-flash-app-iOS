//
//  Alert.swift
//  Calliope App
//
//  Created by Calliope on 07.08.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

struct AlertModifier: ViewModifier {
    @Binding var alert: (any AppAlert)?
    @State var textFieldContent: String = ""

    func body(content: Content) -> some View {
        content.alert(
            alert?.title ?? "",
            isPresented: .isPresent($alert),
            presenting: alert
        ) { alert in
            textFieldAppAlertContent
            standardAppAlertContent
        } message: { alert in
            if let message = alert.message {
                Text(message)
            }
        }
    }
    
    @ViewBuilder
    var standardAppAlertContent: some View {
        if !(alert is any TextFieldAppAlert) {
            ForEach(alert?.actions ?? []) { action in
                Button(action.title, role: action.role) {
                    action.execute()
                }
            }
        }
    }
    
    
    @ViewBuilder
    var textFieldAppAlertContent: some View {
        if alert is any TextFieldAppAlert {
            let textFieldAlert = alert as! any TextFieldAppAlert
            TextField(textFieldAlert.textFieldHint, text: $textFieldContent).onAppear {
                textFieldContent = textFieldAlert.textFieldDefault ?? ""
            }
            ForEach(textFieldAlert.textActions) { action in
                Button(action.title, role: action.role) {
                    textFieldAlert.textActions.forEach { action in
                        action.updateText(text: textFieldContent)
                    }
                    action.execute()
                }
            }

        }
    }
}

extension Binding {
    static func isPresent<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                value.wrappedValue != nil
            },
            set: { isPresented in
                if !isPresented {
                    value.wrappedValue = nil
                }
            }
        )
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

protocol Alertable: AnyObject {
    var alert: (any AppAlert)? { get set }
}

protocol CanShowProgess: AnyObject {
    var progress: (any ProgressAlert)? { get set }
}

protocol ProgressAlert {

}

