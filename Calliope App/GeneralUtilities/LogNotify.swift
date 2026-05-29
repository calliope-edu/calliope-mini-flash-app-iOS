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
    
    public class func info(_ msg: String, fileName: String = #file, lineNumber: Int = #line) {
        LogNotify.log(msg, level: LogNotify.LEVEL.INFO, fileName: fileName, lineNumber: lineNumber)
    }
    
    public class func debug(_ msg: String, fileName: String = #file, lineNumber: Int = #line) {
        LogNotify.log(msg, level: LogNotify.LEVEL.DEBUG, fileName: fileName, lineNumber: lineNumber)
    }
    
    public class func error(_ msg: String, fileName: String = #file, lineNumber: Int = #line) {
        LogNotify.log(msg, level: LogNotify.LEVEL.ERROR, fileName: fileName, lineNumber: lineNumber)
    }
}
