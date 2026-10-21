//
//  USBDestinationPickerViewModel.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

final class USBDestinationPickerViewModel: ObservableObject, USBDestinationPicker {

    struct Request {
        let id = UUID()
        let filename: String
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

    func pickDestination(filename: String, completion: @escaping (Result<URL, Error>?) -> Void) {
        request = Request(filename: filename, completion: completion)
    }

    // A nil result means the user cancelled the export picker.
    func complete(_ result: Result<URL, Error>?) {
        guard let request else { return }
        self.request = nil
        request.completion(result)
    }
}
