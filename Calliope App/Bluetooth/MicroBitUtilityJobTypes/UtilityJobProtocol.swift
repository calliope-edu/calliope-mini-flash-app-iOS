import Foundation

protocol UtilityJobProtocol {
    var id: UInt8 { get }
    var jobState: UtilityJobState.External { get }
    var progress: Int { get }
    var result: Data { get }

    var allowedFormats: Set<BLEDataTypes.UtilityRequest.Format> { get }

    func start() throws
    func handle(response data: Data) throws

    func abort(due reason: UtilityJobState.External)

}

extension UtilityJobProtocol {
    func buildRequest(_ id: UInt8, _ format: UInt8, _ type: UInt8, _ additional: UInt32...) -> Data {
        var response = Data([id, format, type, 0])
        response.append(contentsOf: additional.flatMap {
            $0.littleEndianData
        })
        return response
    }
}