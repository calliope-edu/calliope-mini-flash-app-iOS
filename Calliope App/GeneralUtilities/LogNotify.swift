import Foundation

class LogNotify {

    enum LEVEL: String {
        case INFO, DEBUG, ERROR
    }


    static let logNotifyName = Notification.Name("cc.calliope.mini.logger")

    public class func log(_ msg: @autoclosure () -> String, level: LEVEL = .INFO, fileName: String = #file, lineNumber: Int = #line) {
        #if DEBUG
        let lastPathComponent = (fileName as NSString).lastPathComponent
        let filenameOnly = lastPathComponent.components(separatedBy: ".")[0]
        let extendedMessage = "[\(level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0))] [\(filenameOnly):\(lineNumber)] \(msg())"
        NSLog(extendedMessage)
        #endif
    }

}
