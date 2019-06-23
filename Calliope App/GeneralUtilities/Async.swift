import Foundation
import UIKit

func applySemaphore<T>(_ semaphore: DispatchSemaphore, _ block: () throws -> T) throws -> T {
	semaphore.wait()
	do {
		let result = try block()
		semaphore.signal()
		return result
	} catch {
		semaphore.signal()
		throw error
	}
}

func applySemaphore<T>(_ semaphore: DispatchSemaphore, _ block: () -> T) -> T {
	semaphore.wait()
	let result = block()
	semaphore.signal()
	return result
}

func asyncAndWait<T>(on queue: DispatchQueue, after deadline: DispatchTime? = nil, _ block: @escaping () -> T) -> T {
	var didFinish = false
	var result: T?
	let runLoop = CFRunLoopGetCurrent()
	let asyncBlock = {
		result = block()
		didFinish = true
		CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes?.rawValue) {
			CFRunLoopStop(runLoop)
		}
		CFRunLoopWakeUp(runLoop)
	}
	if let deadline = deadline {
		queue.asyncAfter(deadline: deadline, execute: asyncBlock)
	} else {
		queue.async(execute: asyncBlock)
	}
	while !didFinish {
		CFRunLoopRun()
	}
	return result!
}

func async(_ queue: DispatchQueue = DispatchQueue.global(qos: .background), _ block: @escaping (() throws -> Void)) -> Worker<String> {
    return Worker { resolve in
        
        queue.async {
            do {
                try block()
                DispatchQueue.main.async {
                    resolve(Result("Work is done.", true))
                }
            } catch {
                DispatchQueue.main.async {
                    resolve(Result("Error: \(error)", false))
                }
            }
        }
        
    }
}

@discardableResult
func delay(queue: DispatchQueue = DispatchQueue.main, time: Double, _ block: @escaping (() -> Void)) -> DispatchWorkItem {
	let dwi = DispatchWorkItem(block: block)
    let when = DispatchTime.now() + time
	queue.asyncAfter(deadline: when, execute: dwi)
	return dwi
}

struct Result<T> {
	private(set) var value: T
	private(set) var success: Bool

	public init(_ value: T, _ success: Bool) {
		self.value = value
		self.success = success
	}
}

struct Worker<T> {
	public typealias ResultType = Result<T>
	private let work: ( @escaping (ResultType) -> ()) -> ()

	public init(resolve: @escaping ( @escaping (ResultType) -> ()) -> ()) {
		self.work = resolve
	}

	public func done(_ completion: @escaping (_ value: T, _ success: Bool) -> ()) {
		self.work() { result in
			completion(result.value, result.success)
		}
	}
}
