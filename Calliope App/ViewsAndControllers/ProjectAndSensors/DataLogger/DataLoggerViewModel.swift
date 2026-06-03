//
//  DataLoggerViewModel.swift
//  Calliope App
//
//  Created by Calliope on 03.06.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import Foundation
import SwiftUI

class DataLoggerViewModel: UIViewController {
    
    var html = ""
    var htmlData: Data {
        get {
            html.data(using: .utf8) ?? Data()
        }
        set {
            html = String(decoding: newValue, as: UTF8.self)
        }
    }
    
    @IBSegueAction func addSwiftUI(_ coder: NSCoder) -> UIViewController? {
        return UIHostingController(coder: coder, rootView: DataLoggerView(viewModel: self))
    }
    
    func saveCSV(csv: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("MY_DATA.csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            print("File saved to: \(fileURL.path)")
            showAlert(for: .success)
        } catch {
            print("Error saving file: \(error)")
            showAlert(for: .failure)
        }
    }

    private func showAlert(for status: OperationStatus) {
        let title =
            switch status {
            case .success: NSLocalizedString("Datalogger CSV successfully downloaded!", comment: "")
            default: NSLocalizedString("Failed to download Datalogger CSV!", comment: "")
            }

        let message =
            switch status {
            case .success: NSLocalizedString("You can find the CSV file containing your datalogger data, named MY_DATA.csv, in the Calliope directory on your device.", comment: "")
            default: NSLocalizedString("The download of the CSV file containing your datalogger data was unsuccessful.", comment: "")
            }

        let alert = UIAlertController(
            title: title,
            message: String(format: message),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "OK", style: .cancel) { _ in
                self.dismiss(animated: true)
            }
        )
        self.present(alert, animated: true)
    }
}
