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
//

struct AppAlert: Identifiable {
    struct TextFieldConfig {
        let hint: String
        let defaultValue: String?
        let actions: [TextFieldAlertAction]
    }

    let id = UUID()
    let title: String
    let message: String?
    let actions: [StandardAlertAction]
    let severity: AlertSeverity
    let textField: TextFieldConfig?

    init(
        title: String,
        message: String? = nil,
        actions: [StandardAlertAction] = [],
        severity: AlertSeverity? = nil,
        textField: TextFieldConfig? = nil
    ) {
        self.title = title
        self.message = message
        self.actions = actions
        self.textField = textField
        // Alerts opt into a stronger severity explicitly; a destructive action implies it on its own.
        self.severity = severity ?? (actions.contains { $0.role == .destructive } ? .destructive : .none)
    }
}

struct AlertModifier: ViewModifier {
    @Binding var alert: AppAlert?
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
    let alert: AppAlert
    @Binding var textFieldContent: String
    let perform: (() -> Void) -> Void
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if alert.severity != .none {
                Rectangle()
                    .fill(alert.severity.color)
                    .frame(height: 8)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    if alert.severity != .none {
                        Image(systemName: alert.severity.icon)
                            .font(.title3)
                            .foregroundColor(alert.severity.color)
                    }
                    Text(alert.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }

                if let message = alert.message {
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let textField = alert.textField {
                    TextField(textField.hint, text: $textFieldContent)
                        .focused($textFieldFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.tertiarySystemFill))
                        )
                        .padding(.top, 4)
                }
            }
            .padding(24)

            buttonArea
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(width: 340)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(radius: 10)
        .task(id: alert.id) {
            textFieldContent = alert.textField?.defaultValue ?? ""
            textFieldFocused = alert.textField != nil
        }
    }

    @ViewBuilder
    private var buttonArea: some View {
        if let textField = alert.textField {
            actionList(textField.actions) { action in
                perform {
                    textField.actions.forEach { $0.updateText(text: textFieldContent) }
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
            HStack(spacing: 12) {
                ForEach(actions) { action in
                    alertButton(action, onSelect: onSelect)
                }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(actions) { action in
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
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundColor(foregroundColor(for: action.role))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(background(for: action.role))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color("calliope-lilablau"), lineWidth: action.role == .cancel ? 1.5 : 0)
                )
        }
    }

    private func foregroundColor(for role: ButtonRole?) -> Color {
        role == .cancel ? Color("calliope-lilablau") : .white
    }

    private func background(for role: ButtonRole?) -> Color {
        switch role {
        case .destructive:
            return .calliopeRed
        case .cancel:
            return .clear
        default:
            return Color("calliope-lilablau")
        }
    }
}

enum AlertSeverity: Equatable {
    case none
    case warning
    case destructive

    var color: Color {
        switch self {
        case .none:
            return Color("calliope-lilablau")
        case .warning:
            return .calliopeOrange
        case .destructive:
            return .calliopeRed
        }
    }

    var icon: String {
        switch self {
        case .none:
            return ""
        case .warning:
            return "exclamationmark.triangle.fill"
        case .destructive:
            return "trash.fill"
        }
    }
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
        _ alert: Binding<AppAlert?>
    ) -> some View {
        modifier(AlertModifier(alert: alert))
    }
}

protocol Alertable: AnyObject {
    var alert: AppAlert? { get set }
}

extension Alertable {
    func setAlert(_ newAlert: AppAlert?) {
        alert = newAlert
    }
}

class TestAlertable: Alertable {
    var alert: AppAlert? {
        didSet {
            LogNotify.error("Tried to show alert, but only the TestAlertable was initialized. This should not happen.")
        }
    }
}
