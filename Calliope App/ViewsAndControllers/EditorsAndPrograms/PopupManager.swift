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

            // Custom Alert Overlay
            if let alertPopup = popupManager.currentPopup?.alert {
                CustomAlertView(alert: alertPopup) {
                    popupManager.dismissCurrent()
                }
            }

            // Custom Progress Overlay
            if let progressPopup = popupManager.currentPopup?.progress {
                CustomProgressView(popup: progressPopup) {
                    popupManager.dismissCurrent()
                }
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
                            message: "This is an extra long test message to see how the width of the message field is limited",
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

struct CustomPopup<Content: View>: View {
    private let content: Content
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Alert Card
            VStack(spacing: 20) {
                content
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

struct CustomAlertView: View {
    let alert: SwiftUIAlert?
    let onDismiss: () -> Void

    var body: some View {
        if let alert = alert {
            CustomPopup(onDismiss: onDismiss) {
                Text(alert.title)
                    .font(.headline)

                if let message = alert.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Text Field
                if let textField = alert.textField {
                    TextField(textField.title, text: textField.text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 300)
                }

                // Actions
                HStack(spacing: 15) {
                    ForEach(alert.actions) { action in
                        Button(action.title) {
                            action.action()
                            onDismiss()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(action.role == .cancel ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
                        )
                        .foregroundColor(action.role == .cancel ? .primary : .blue)
                    }
                }
            }
        }
    }
}

struct CustomProgressView: View {
    let popup: ProgressPopup?
    let onDismiss: () -> Void

    var body: some View {
        if let popup = popup {
            CustomPopup(onDismiss: onDismiss) {
                Text(popup.title)
                    .font(.headline)

                ProgressView(value: popup.progress)
                    .progressViewStyle(CustomCircularProgressViewStyle())
                    .frame(width: 150, height: 150)

                Button("Cancel") {
                    popup.onCancel()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
                .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    PopupDemo()
}
