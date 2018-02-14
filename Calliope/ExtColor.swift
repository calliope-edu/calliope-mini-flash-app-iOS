import UIKit

extension UIColor {

   convenience init(hex:Int) {
        let r = (hex >> 16) & 0xff
        let g = (hex >> 8) & 0xff
        let b = hex & 0xff
       self.init(red:CGFloat(r)/255.0, green:CGFloat(g)/255.0, blue:CGFloat(b)/255.0, alpha: 1.0)
   }
}
