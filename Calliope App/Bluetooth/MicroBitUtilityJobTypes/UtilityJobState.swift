import Foundation

enum UtilityJobState {
    enum External {
        // Base Cases
        case Initial
        case Running
        case Finished
        case Canceled

        // Error Cases
        case None
        case BleError
        case V2Only
        case NoService
        case ProtocolError
        case NoData
        case OutOfMemor
    }

    enum Internal {
        enum LogFetching {
            case LogLength
            case LogData
            case Finished
        }
    }
}
