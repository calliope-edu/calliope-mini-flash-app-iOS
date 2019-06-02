import Foundation

class LogNotify {
    
    static let logNotifyName = Notification.Name("cc.calliope.mini.logger")
    
    public class func log(_ msg: @autoclosure () -> String) {

		NSLog(msg())

		/*
		if DebugConstants.debugMessages {

			let message = msg()

			let main = Thread.current.isMainThread
			let thread = main ? "[main]" : "[back]"

			let formatter = DateFormatter()
			formatter.dateFormat = "HH:mm:ssss"
			let now = formatter.string(from: Date())
			NSLog("LogNotify:: \(thread) : \(message)")

			if (DebugConstants.debugView) {
				let userInfo = ["message":message, "date":now]
				let notification = Notification(name: logNotifyName, object: nil, userInfo: userInfo)

				//this seems to have been synchronous, so no matter which queue it was invoked from, if the main queue was waiting the queue had to wait, too. This lead to deadlocks
				DispatchQueue.main.async {
					if (PlaygroundPage.current.liveView as? PlaygroundRemoteLiveViewProxy) != nil {
						PlayGroundManager.shared.sendNotification(notification)
					} else {
						NotificationCenter.default.post(notification)
					}
				}

			}
		}*/
    }
    
}
