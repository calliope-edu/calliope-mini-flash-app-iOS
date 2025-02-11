import Foundation

protocol UtilityJobProtocol {
    var id: UInt8 { get }
    var state: UtilityJobState.External { get }
    var result: Data { get }

    var allowedFormats: Set<BLEDataTypes.UtilityRequest.Format> { get }

    func start(respond: (Data) throws -> ()) throws
    func handle(response data: Data, respond: (Data) throws -> ()) throws


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