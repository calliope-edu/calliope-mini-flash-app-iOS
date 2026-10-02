import Foundation

class LogNotify {

    enum LEVEL: String {
        case INFO, DEBUG, ERROR
    }


    static let logNotifyName = Notification.Name("cc.calliope.mini.logger")

    // MARK: - In-memory log buffer
    //
    // NSLog output is compiled out in Release, and a Shared iPad can only be
    // updated through TestFlight — so there is no Xcode console to read. To keep
    // field problems diagnosable, the most recent lines are also kept in a small
    // in-memory ring buffer that the app can share on request. Nothing is written
    // to disk and nothing is sent anywhere automatically.

    private static let bufferLimit = 200
    private static var buffer: [String] = []
    private static let bufferLock = NSLock()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// The buffered log lines, oldest first — for sharing from within the app.
    public static var recentLog: String {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return buffer.joined(separator: "\n")
    }

    /// The most recent buffered lines that contain one of `keywords`, oldest
    /// first, capped at `limit` — short enough to show inside an alert.
    public static func recentLines(matching keywords: [String], limit: Int) -> String {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        let relevant = keywords.isEmpty
            ? buffer
            : buffer.filter { line in keywords.contains(where: { line.contains($0) }) }
        return relevant.suffix(limit).joined(separator: "\n")
    }

    public class func log(_ msg: @autoclosure () -> String, level: LEVEL = .INFO, fileName: String = #file, lineNumber: Int = #line) {
        let lastPathComponent = (fileName as NSString).lastPathComponent
        let filenameOnly = lastPathComponent.components(separatedBy: ".")[0]
        let extendedMessage = "[\(level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0))] [\(filenameOnly):\(lineNumber)] \(msg())"

        bufferLock.lock()
        let stamped = timestampFormatter.string(from: Date()) + " " + extendedMessage
        buffer.append(stamped)
        if buffer.count > bufferLimit {
            buffer.removeFirst(buffer.count - bufferLimit)
        }
        bufferLock.unlock()

        #if DEBUG
        NSLog(extendedMessage)
        #endif
    }

}
