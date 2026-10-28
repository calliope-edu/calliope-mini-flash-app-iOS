//
//  DiagnosticsFolderPicker.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

final class DiagnosticsFolderPicker: ObservableObject {

    struct Request {
        let id = UUID()
        let completion: (Result<URL, Error>?) -> Void
    }

    @Published private(set) var request: Request?

    var isPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.request != nil },
            set: { isPresented in
                guard !isPresented, let request = self.request else { return }
                // iOS 16 has no cancel callback; the delay lets a success result arrive first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard self.request?.id == request.id else { return }
                    self.complete(nil)
                }
            }
        )
    }

    // MARK: - Public API

    // A nil result means the user cancelled.
    func pickFolder(completion: @escaping (Result<URL, Error>?) -> Void) {
        request = Request(completion: completion)
    }

    func complete(_ result: Result<URL, Error>?) {
        guard let request else { return }
        self.request = nil
        request.completion(result)
    }
}

struct DiagnosticsFolderPickerModifier: ViewModifier {
    @ObservedObject var picker: DiagnosticsFolderPicker

    func body(content: Content) -> some View {
        // Same content types as the folder picker in the connection panel.
        content.fileImporter(isPresented: picker.isPresentedBinding, allowedContentTypes: [.folder, .directory, .volume]) { result in
            picker.complete(result)
        }
    }
}
