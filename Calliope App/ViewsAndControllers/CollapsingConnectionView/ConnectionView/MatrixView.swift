import UIKit

final class MatrixView: UIView {

	public var updateBlock: () -> () = {}
	public var onChange: ([[Bool]]) -> () = {_ in }

    var matrix = [
        [ false, false, false, false, false ],
        [ false, false, false, false, false ],
        [ false, false, false, false, false ],
        [ false, false, false, false, false ],
        [ false, false, false, false, false ],
		] {
		didSet {
			setNeedsDisplay()
		}
	}
    let nx = 5
    let ny = 5

    var draw = true

	override var intrinsicContentSize: CGSize {
		return CGSize(width: 200, height: 200)
	}

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for (i, touch) in touches.enumerated() {
            let point = touch.location(in: self)
            let x = max(0, min(nx-1, Int(CGFloat(nx) * point.x/gx)))
            let y = max(0, min(nx-1, Int(CGFloat(ny) * point.y/gy)))

            if i == 0 {
                draw = !matrix[x][y]
            }

            matrix[x][y] = draw
        }
        setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let x = max(0, min(nx-1, Int(CGFloat(nx) * point.x/gx)))
            let y = max(0, min(nx-1, Int(CGFloat(ny) * point.y/gy)))
            matrix[x][y] = draw
        }
        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let x = max(0, min(nx-1, Int(CGFloat(nx) * point.x/gx)))
            let y = max(0, min(nx-1, Int(CGFloat(ny) * point.y/gy)))
            matrix[x][y] = draw
        }
        updateBlock()
    }
    
    func isBlank() -> Bool {
        for b1 in matrix {
            for b2 in b1 {
                if b2 { return false }
            }
        }
        return true
    }
    
    func getMatrixString() -> String {
        var result = ""
        for b1 in matrix {
            for b2 in b1 {
                result += (b2 ? "1" : "0")
            }
        }
        return result
    }
    
    func setMatrixString(pattern:String) {
        if pattern.count != getMatrixString().count { return }
        
        var index = 0
        for (i1,b1) in matrix.enumerated() {
            for (i2,_) in b1.enumerated() {
                matrix[i1][i2] = (pattern[index] == "1") ? true : false
                index += 1
            }
        }
    }

    let sf = 0.03

    var sx: CGFloat {
        get {
            return bounds.size.width * CGFloat(sf)
        }
    }

    var sy: CGFloat {
        get {
            return bounds.size.height * CGFloat(sf)
        }
    }


    var gx: CGFloat {
        get {
            return bounds.size.width + sx
        }
    }

    var gy: CGFloat {
        get {
            return bounds.size.height + sy
        }
    }

    override func draw(_ rect: CGRect) {
        let bx = gx * 1 / CGFloat(nx) - sx
        let by = gy * 1 / CGFloat(ny) - sy
        for y in 0..<ny {
            for x in 0..<nx {
                let box = UIBezierPath(rect: CGRect(
                    x: gx * CGFloat(x) / CGFloat(nx),
                    y: gy * CGFloat(y) / CGFloat(ny),
                    width: bx,
                    height: by
                ))
                if matrix[x][y] {
					UIColor(named: "calliope-pink")!.setFill()
                } else {
					UIColor.white.setFill()
                }
                box.fill()
            }
        }
    }
}
