import Foundation

class UtilityLogJob: UtilityJobProtocol {
    var id: UInt8
    private var subId: UInt8 = 0x00;

    // State relevant
    var jobState: UtilityJobState.External
    private var protocolState: UtilityJobState.Internal.LogFetching

    var progress: Int {
        get {
            guard let logLength = logLength else {
                return 0
            }
            return Int((result.count * 100 / Int(logLength)))
        }
    }

    private var timeoutDispatch: DispatchWorkItem?

    var result: Data = Data()

    var allowedFormats: Set<BLEDataTypes.UtilityRequest.Format> = [.LOG_HTML_HEADER, .LOG_HTML, .LOG_CSV]

    private var format: BLEDataTypes.UtilityRequest.Format

    // Log reading relevant data
    private var logLength: UInt32?
    private var batchIndex: UInt32 = 0
    private var batchSize: UInt32 = 0

    // Callbacks

    private let sendResponse: (Data) throws -> ()
    private let onAbortCallback: () -> ()
    private let onFinishedCallback: () -> ()


    init(id: UInt8, format: BLEDataTypes.UtilityRequest.Format, onRespond sendResponse: @escaping (Data) throws -> (), onAbort onAbortCallback: @escaping () -> (), onFinish onFinishedCallback: @escaping () -> ()) {
        self.id = id

        // State
        self.jobState = .Initial
        self.protocolState = .LogLength

        // Protocol Relevant Settings
        self.format = format;

        // callbacks
        self.sendResponse = sendResponse
        self.onAbortCallback = onAbortCallback
        self.onFinishedCallback = onFinishedCallback
    }

    func start() throws {
        guard jobState == .Initial && protocolState == .LogLength else {
            LogNotify.log("Expected job to be in state \(UtilityJobState.External.Initial), yet is in \(jobState)")
            return
        }

        do {
            id = id < 0xF0 ? id + 0x10 : 0x00
            subId = 0
            let request = buildRequest(id, BLEDataTypes.UtilityRequest.Type_.LOG_LENGTH.rawValue, format.rawValue)
            LogNotify.log("LogLengthRequest(0x\(request.hexEncodedString()))")
            try sendResponse(request)
        } catch {
            abort(due: .BleError)
            throw error
        }

        startTimeout()
        jobState = .Running
    }

    func handle(response data: Data) throws {
        // Validate correct state and job response
        guard jobState == .Running && protocolState != .Finished else {
            throw "Expected job to be in state \(UtilityJobState.External.Running), yet is in \(jobState)"
        }

        timeoutDispatch?.cancel()

        let id = data.first!
        guard id & 0xF0 == self.id else {
            return
        }

        guard (id & 0x0F) != 0x0F else {
            abort(due: .ProtocolError)
            throw "Received Job error."
        }

        guard (id & 0x0F) == subId else {
            abort(due: .ProtocolError)
            throw "Received Response out of order."
        }

        // move expected next subid up
        subId = subId < 0x0F ? subId + 1 : 0x00

        // process response
        let response: Data? = switch protocolState {
        case .LogLength:
            try handleLogLengthResponse(data)
        case .LogData:
            try handleLogDataResponse(data)
        case .Finished:
            throw "unreachable case"
        }

        // finished either due to error or protocol completed
        if (protocolState == .Finished) {
            if (jobState == .Finished) {
                onFinishedCallback();
            }
            return
        }

        // Either waiting or sending next batch request
        if (response != nil) { // Got latest batch
            try sendResponse(response!)
        }
        startTimeout()
    }

    func abort(due reason: UtilityJobState.External) {
        // correct state
        jobState = reason
        protocolState = .Finished

        // cleanup
        timeoutDispatch?.cancel()

        // callback
        onAbortCallback()
    }

    private func handleLogLengthResponse(_ data: Data) throws -> Data {
        guard data.count > 4 else {
            abort(due: .ProtocolError)
            throw "Received malformed log length response"
        }

        let logLength = Int(littleEndianData: data.subdata(in: 1..<5).padded(to: 8, with: 0x00))
        self.logLength = UInt32(logLength ?? 0)
        guard let logLenght = logLength, logLenght > 0 else {
            abort(due: .ProtocolError)
            throw "No Log Data available"
        }

        result.reserveCapacity(Int(logLenght))
        protocolState = .LogData
        return buildNextLogDataRequest()
    }


    private func handleLogDataResponse(_ data: Data) throws -> Data? {
        guard data.count > 1 else {
            abort(due: .ProtocolError)
            throw "No log data in response"
        }

        result.append(data.subdata(in: 1..<data.count))
        batchIndex += UInt32(data.count - 1)

        if batchIndex != batchSize { // batch not completed .. cont waiting
            return nil
        }

        if logLength! <= result.count { // all data processed
            protocolState = .Finished
            jobState = .Finished
            return nil
        }

        return buildNextLogDataRequest()
    }

    private func buildNextLogDataRequest() -> Data {
        id = id < 0xF0 ? id + 0x10 : 0x00
        subId = 0

        batchIndex = 0
        batchSize = min(logLength! - UInt32(result.count), UInt32(19 * 4))
        let request = buildRequest(
            id,
            BLEDataTypes.UtilityRequest.Type_.LOG_READ.rawValue,
            format.rawValue,
            UInt32(result.count),
            batchSize,
            logLength!)

        LogNotify.log("LogDataRequest(0x\(request.hexEncodedString()))")
        return request
    }

    private func startTimeout() {
        guard protocolState != .Finished && jobState == .Running else {
            return
        }

        timeoutDispatch = delay(time: 2.0) { [self] in
            LogNotify.log("Job abort due to timeout")
            abort(due: .BleError)
        }
    }
}