import UIKit
import SwiftUI

extension UIColor {

   convenience init(hex:Int) {
        let r = (hex >> 16) & 0xff
        let g = (hex >> 8) & 0xff
        let b = hex & 0xff
       self.init(red:CGFloat(r)/255.0, green:CGFloat(g)/255.0, blue:CGFloat(b)/255.0, alpha: 1.0)
   }
}

extension Color  {
    init?(hex:String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        guard hexSanitized.count == 6 else { return nil }
        
        var rgbValue: UInt64 = 0
        let scanner = Scanner(string: hexSanitized)
        
        guard scanner.scanHexInt64(&rgbValue) else { return nil }
        
        let r = Int((rgbValue & 0xFF0000) >> 16)
        let g = Int((rgbValue & 0x00FF00) >> 8)
        let b = Int(rgbValue & 0x0000FF)

        self.init(red:CGFloat(r)/255.0, green:CGFloat(g)/255.0, blue:CGFloat(b)/255.0)
    }
}

