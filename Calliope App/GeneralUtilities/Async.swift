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

@discardableResult
func delay(queue: DispatchQueue = DispatchQueue.main, time: Double, _ block: @escaping (() -> Void)) -> DispatchWorkItem {
	let dwi = DispatchWorkItem(block: block)
	let when = DispatchTime.now() + time
	queue.asyncAfter(deadline: when, execute: dwi)
	return dwi
}

