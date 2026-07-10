import Foundation
import UIKit

final class Matrix {

    static let MICROBIT_NAME_LENGTH = 5
    static let MICROBIT_NAME_CODE_LETTERS = 5
    static let MICROBIT_DFU_HISTOGRAM_HEIGHT = 5
    static let MICROBIT_DFU_HISTOGRAM_WIDTH = 5

    static let codebook = [
        ["z", "v", "g", "p", "t"],
        ["u", "o", "i", "e", "a"],
        ["z", "v", "g", "p", "t"],
        ["u", "o", "i", "e", "a"],
        ["z", "v", "g", "p", "t"],
    ]

    static func matrix2heights(_ matrix: [[Bool]]) -> [Int]? {
        guard let rowCount = matrix.first?.count else {
            return []
        }

        var heights = [Int]()

        for columnIndex in 0..<rowCount {
            let column = matrix.map { $0[columnIndex] }

            let topFalses = column.prefix { !$0 }.count
            let bottomTrues = column.reversed().prefix { $0 }.count

            guard topFalses + bottomTrues == column.count else {
                return nil
            }

            heights.append(bottomTrues)
        }

        return heights
    }

    static func heights2friendly(_ heights: [Int]) -> String? {
        guard heights.count == MICROBIT_NAME_LENGTH else { return nil }
        var name = ""
        for i in 0..<MICROBIT_NAME_LENGTH {
            let h = heights[i]
            guard h > 0 && h <= 5 else { return nil }
            name.append(codebook[i][h - 1])
        }
        return name
    }

    static func matrix2friendly(_ matrix: [[Bool]]) -> String? {
        guard let heights = matrix2heights(matrix) else { return nil }
        return heights2friendly(heights)
    }

    static func full2Friendly(fullName: String) -> String? {
        let bracket = CharacterSet(charactersIn: "[")
        let brackets = CharacterSet(charactersIn: "[]")
        let scanner = Scanner(string: fullName)
        scanner.charactersToBeSkipped = brackets
        var maybefriendly: String?

        _ = scanner.scanUpToCharacters(from: bracket)
        maybefriendly = scanner.scanUpToCharacters(from: brackets)

        guard let friendly: String = maybefriendly as String? else {
            LogNotify.log("no friendly name found")
            return nil
        }

        return Matrix.validateFriendly(friendly) ? friendly : nil
    }

    static func validateFriendly(_ friendly: String) -> Bool {
        guard friendly.count == MICROBIT_NAME_LENGTH else {
            LogNotify.log("friendly count wrong")
            return false
        }
        let codeFlat = Array(Set(codebook.flatMap { return $0 })).joined(separator: "")
        let codeSet = CharacterSet(charactersIn: codeFlat)
        guard friendly.trimmingCharacters(in: codeSet).count == 0 else {
            LogNotify.log("friendly contains false charaters")
            return false
        }
        return true
    }

    static func friendly2Heights(_ friendly: String) -> [Int] {
        // assumes friendly is validated
        var heights: [Int] = []
        for (idx, char) in friendly.enumerated() {
            if let i = codebook[idx].firstIndex(where: { $0 == String(char) }) {
                heights.append(i)
            }
        }
        return heights
    }

    static func friendly2Matrix(_ friendly: String) -> [[Bool]] {
        let heights = friendly2Heights(friendly)

        return (0..<MICROBIT_NAME_LENGTH)
            .map { row in
                heights.map { height in
                    row + 1 >= MICROBIT_NAME_LENGTH - height
                }
            }
    }

    static func heights2MatrixImage(heights: [Int], rect: CGRect) -> UIImage? {
        let len = MICROBIT_NAME_LENGTH - 1
        let insetPerc: CGFloat = 0.8
        let max_size = max(rect.size.width, rect.size.height)
        let size = max_size * insetPerc
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)

        let bw = (size / 13)
        let bh = (size / 7)
        let bwo = bw * 2.0
        let bho = bh / 2.0

        for x in 0...len {
            for y in 0...len {
                let box = UIBezierPath(
                    roundedRect: CGRect(
                        x: CGFloat(x) * (bw + bwo),
                        y: CGFloat(y) * (bh + bho),
                        width: bw,
                        height: bh
                    ),
                    cornerRadius: 2.0
                )
                if (len - y) <= heights[x] {
                    UIColor.red.setFill()
                } else {
                    UIColor.white.setFill()
                }
                box.fill()
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
