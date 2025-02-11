import Foundation

class UtilityLogJob: UtilityJobProtocol {
    var id: UInt8
    private var subId: UInt8 = 0x00;

    // State relevant
    var state: UtilityJobState.External
    private var internalState: UtilityJobState.Internal.LogFetching

    var result: Data = Data()

    var allowedFormats: Set<BLEDataTypes.UtilityRequest.Format> = [.LOG_HTML_HEADER, .LOG_HTML, .LOG_CSV]

    private var format: BLEDataTypes.UtilityRequest.Format

    // Log reading relevant data
    private var logLength: UInt32?
    private var batchIndex: UInt32 = 0
    private var batchSize: UInt32 = 0


    init(id: UInt8, format: BLEDataTypes.UtilityRequest.Format) {
        self.id = id

        // State
        self.state = .Initial
        self.internalState = .LogLength

        // Protocol Relevant Settings
        self.format = format;
    }

    func start(respond: (Data) throws -> ()) throws {
        guard state == .Initial && internalState == .LogLength else {
            LogNotify.log("Expected job to be in state \(UtilityJobState.External.Initial), yet is in \(state)")
            return
        }

        do {
            try respond(buildRequest(id, format.rawValue, BLEDataTypes.UtilityRequest.Type_.LOG_LENGTH.rawValue))
        } catch {
            state = .BleError
            throw error
        }
        state = .Running
    }

    func handle(response data: Data, respond: (Data) throws -> ()) throws {
        // Validate correct state and job response
        guard state == .Running else {
            throw "Expected job to be in state \(UtilityJobState.External.Running), yet is in \(state)"
        }

        let id = data.first!

        guard (id & 0x0F) != 0x0F else {
            state = .ProtocolError
            throw "Received Job error."
        }

        guard (id & 0x0F) == subId else {
            state = .ProtocolError
            throw "Received Response out of order."
        }

        // move expected lower down
        subId = subId < 0x0F ? subId + 1 : 0x00
        let response: Data? = switch internalState {
        case .LogLength:
            try handleLogLengthResponse(data)
        case .LogData:
            try handleLogDataResponse(data)
        case .Finished:
            throw "unreachable case"
        }

        guard let response = response else {
            return
        }
        try respond(response)
    }

    private func handleLogLengthResponse(_ data: Data) throws -> Data {
        guard data.count > 4 else {
            state = .ProtocolError
            throw "Received malformed log length response"
        }

        let logLength = Int(littleEndianData: data.subdata(in: 1..<4))
        self.logLength = UInt32(logLength ?? 0)
        guard let logLenght = logLength, logLenght > 0 else {
            state = .ProtocolError
            throw "No Log Data available"
        }

        result.reserveCapacity(Int(logLenght))
        return buildNextLogDataRequest()
    }


    private func handleLogDataResponse(_ data: Data) throws -> Data? {
        guard data.count > 1 else {
            state = .ProtocolError
            throw "No log data in response"
        }

        result.append(data.subdata(in: 1..<data.count))
        batchIndex += UInt32(data.count - 1)
        if batchIndex != batchSize { // batch not completed .. cont waiting
            return nil
        }

        if logLength! != result.count { // all data processed
            state = .Finished
            return nil
        }

        return buildNextLogDataRequest()
    }

    private func buildNextLogDataRequest() -> Data {
        batchIndex = 0
        batchSize = min(logLength! - UInt32(result.count), UInt32(19 * 4))
        return buildRequest(id, format.rawValue, BLEDataTypes.UtilityRequest.Type_.LOG_READ.rawValue, UInt32(result.count), batchSize, logLength!)

    }
}