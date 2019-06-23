import Foundation

class LogNotify {

	static let debug = true
    
    static let logNotifyName = Notification.Name("cc.calliope.mini.logger")

    public class func log(_ msg: @autoclosure () -> String, fileName: String = #file, lineNumber: Int = #line) {
		if debug {
			let lastPathComponent = (fileName as NSString).lastPathComponent
			let filenameOnly = lastPathComponent.components(separatedBy: ".")[0]
			let extendedMessage = "\(filenameOnly):\(lineNumber) \(msg())"
			NSLog(extendedMessage)
		}
    }
    
}
