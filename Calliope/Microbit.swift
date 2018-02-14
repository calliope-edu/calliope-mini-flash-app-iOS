
final class Microbit {

    static let MICROBIT_NAME_LENGTH = 5
    static let MICROBIT_NAME_CODE_LETTERS = 5
    static let MICROBIT_DFU_HISTOGRAM_HEIGHT = 5
    static let MICROBIT_DFU_HISTOGRAM_WIDTH = 5

    static let codebook = [
        ["z", "v", "g", "p", "t"],
        ["u", "o", "i", "e", "a"],
        ["z", "v", "g", "p", "t"],
        ["u", "o", "i", "e", "a"],
        ["z", "v", "g", "p", "t"]
    ]

    static func matrix2heights(_ matrix:[[Bool]]) -> [Int]? {
        var heights = [Int]()
        for col in matrix {
            let h0 = col.reversed().reduce(0,{ (h,v) in
                return v ? 0 : h + 1
            })
            let h1 = col.reduce(0,{ (h,v) in
                return v ? h + 1 : 0
            })
            guard h0 + h1 == col.count else { return nil }
            heights.append(h1)
        }
        return heights
    }

    static func heights2friendly(_ heights: [Int]) -> String? {
        guard heights.count == MICROBIT_NAME_LENGTH else { return nil }
        var name = ""
        for i in 0..<MICROBIT_NAME_LENGTH {
            let h = heights[i]
            guard h > 0 && h <= 5 else { return nil }
            name.append(codebook[i][h-1])
        }
        return name
    }

    static func matrix2friendly(_ matrix:[[Bool]]) -> String? {
        guard let heights = matrix2heights(matrix) else { return nil }
        return heights2friendly(heights)
    }
}
