//
//  PopupManager.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

@MainActor
final class PopupManager: ObservableObject {
    static let instance = PopupManager()
    private var popups: [Popup] = []
    @Published var currentPopup: Popup? = nil

    func show(_ popup: Popup) {
        if currentPopup == nil {
            currentPopup = popup
        } else {
            popups.append(popup)
        }
    }

    func dismiss(id: UUID) {
        popups.removeAll { $0.id == id }
        if currentPopup != nil && currentPopup!.id == id {
            dismissCurrent()
        }
    }

    func dismissCurrent() {
        if popups.isEmpty {
            currentPopup = nil
        } else {
            currentPopup = popups.removeFirst()
        }
    }

    func updateProgress(id: UUID, progress: Double) {
        if currentPopup != nil && currentPopup!.id == id {
            if let progressPopup = currentPopup?.progress {
                progressPopup.progress = progress
                objectWillChange.send()
            }
        } else {
            if let progressPopup = popups.first { $0.id == id }?.progress {
                progressPopup.progress = progress
            }
        }
    }
}

struct PopupRoot<Content: View>: View {
    @ObservedObject private var popupManager = PopupManager.instance
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .sheet(
                    isPresented: Binding(
                        get: { popupManager.currentPopup?.progress != nil },
                        set: { if !$0 { popupManager.dismissCurrent() } }
                    )
                ) {
                    VStack {
                        Text(popupManager.currentPopup?.progress?.title ?? "Transmission running")
                        ProgressView(
                            value: popupManager.currentPopup?.progress?.progress ?? 0
                        )
                        .progressViewStyle(CustomCircularProgressViewStyle())
                        .frame(width: 150, height: 150)
                        .padding()
                        Button("Cancel") { popupManager.dismissCurrent() }
                    }
                }
                .alert(
                    popupManager.currentPopup?.alert?.title ?? "",
                    isPresented: Binding(
                        get: { popupManager.currentPopup?.alert != nil },
                        set: { if !$0 { popupManager.dismissCurrent() } }
                    )
                ) {
                    if popupManager.currentPopup?.alert != nil && popupManager.currentPopup!.alert!.textField != nil {
                        TextField(popupManager.currentPopup!.alert!.textField!.title, text: popupManager.currentPopup!.alert!.textField!.text)
                    }
                    ForEach(popupManager.currentPopup?.alert?.actions ?? []) { action in
                        Button(action.title, role: action.role) {
                            popupManager.dismissCurrent()
                            action.action()
                        }
                    }
                } message: {
                    Text(popupManager.currentPopup?.alert?.message ?? "")
                }
        }
    }
}

enum Popup: Identifiable {
    case progress(ProgressPopup)
    case alert(SwiftUIAlert)

    var id: UUID {
        switch self {
        case .progress(let p): return p.id
        case .alert(let a): return a.id
        }
    }

    var progress: ProgressPopup? {
        guard case .progress(let popup) = self else { return nil }
        return popup
    }

    var alert: SwiftUIAlert? {
        guard case .alert(let popup) = self else { return nil }
        return popup
    }
}

class ProgressPopup {
    let id = UUID()
    let title: String
    var progress: Double
    let onCancel: () -> Void

    init(title: String, progress: Double = 0, onCancel: @escaping () -> Void) {
        self.title = title
        self.progress = progress
        self.onCancel = onCancel
    }
}

class SwiftUIAlert {
    let id = UUID()
    let title: String
    let message: String?
    let actions: [AlertAction]
    let textField: AlertTextField?

    init(title: String, message: String? = nil, actions: [AlertAction], textField: AlertTextField?) {
        self.title = title
        self.message = message
        self.actions = actions
        self.textField = textField
    }
}

struct AlertAction: Identifiable {
    let id = UUID()
    let title: String
    let role: ButtonRole? = nil
    let action: () -> Void
}

struct AlertTextField {
    let title: String
    let text: Binding<String>
}

class OkAlert: SwiftUIAlert {
    init(title: String, message: String? = nil, completion: @escaping () -> Void = {}) {
        super.init(
            title: title,
            message: message,
            actions: [AlertAction(title: "OK", action: completion)],
            textField: nil
        )
    }
}

class TwoOptionsAlert: SwiftUIAlert {
    init(title: String, message: String? = nil, actions: [AlertAction]) {
        super.init(title: title, message: message, actions: actions, textField: nil)
    }
}

struct PopupDemo: View {
    var body: some View {
        PopupRoot {
            PopupDemoView()
        }
    }
}

struct CustomCircularProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(Color.calliopeYellow, lineWidth: 15)
            Circle()
                .trim(from: 0.0, to: CGFloat(configuration.fractionCompleted ?? 0))
                .stroke(Color.calliopeGreen, lineWidth: 10)
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: configuration.fractionCompleted)
            Text(String(format: "%.0f%%", (configuration.fractionCompleted ?? 0) * 100))
                .font(.title)
                .bold()
        }
    }
}

struct PopupDemoView: View {
    @State var showingFileImporter = false
    @State var textFieldText = ""

    var body: some View {
        VStack {
            Button("Show Alert") {
                PopupManager.instance.show(
                    .alert(
                        SwiftUIAlert(
                            title: "Test title",
                            message: "Test message",
                            actions: [AlertAction(title: "OK", action: {}), AlertAction(title: "Cancel", action: {})],
                            textField: AlertTextField(title: "Test", text: $textFieldText)
                        )
                    )
                )
            }
            SizedBox(height: 10)
            Button("Show Progress View") {
                PopupManager.instance.show(.progress(ProgressPopup(title: "Tranmitting", progress: 0.6, onCancel: {})))
            }
            SizedBox(height: 10)
            Button("Show File Importer") {
                showingFileImporter = true
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item]) { _ in
            }
        }
    }
}

#Preview {
    PopupDemo()
}
