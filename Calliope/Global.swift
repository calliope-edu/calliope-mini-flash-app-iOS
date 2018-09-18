import Foundation
import UIKit

extension String: Error {}

func LOG(_ message: Any, fileName: String = #file, lineNumber: Int = #line) {
    let lastPathComponent = (fileName as NSString).lastPathComponent
    let filenameOnly = lastPathComponent.components(separatedBy: ".")[0]
    let extendedMessage = "\(filenameOnly):\(lineNumber) \(message)"
    
    print(extendedMessage)
}

func ERR(_ message: Any, fileName: String = #file, lineNumber: Int = #line) {
    let lastPathComponent = (fileName as NSString).lastPathComponent
    let filenameOnly = lastPathComponent.components(separatedBy: ".")[0]
    let extendedMessage = "\(filenameOnly):\(lineNumber) \(message)"

    print(extendedMessage)
}

func range(_ r: ClosedRange<Double>) -> CGFloat {
    return range(CGFloat(r.lowerBound), CGFloat(r.upperBound))
}

func range(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
    let minWidth = CGFloat(320)
    let maxWidth = CGFloat(1024)
    // let width = UIScreen.main.bounds.width
    let width = UIApplication.shared.statusBarFrame.width
    // print("WIDTH=\(width)")
    let factor = (width - minWidth) / (maxWidth - minWidth)
    return low + max(0,min(1,factor)) * (high-low)
}

