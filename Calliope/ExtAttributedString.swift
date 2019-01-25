import UIKit

extension NSMutableAttributedString {

    func setBaseFont(baseFont: UIFont, preserveFontSizes: Bool = false) {
        let baseDescriptor = baseFont.fontDescriptor
        beginEditing()
        enumerateAttribute(NSAttributedString.Key.font, in: NSMakeRange(0, length), options: []) { object, range, stop in
            if let font = object as? UIFont {
                // Instantiate a font with our base font's family, but with the current range's traits
                let traits = font.fontDescriptor.symbolicTraits
                let descriptor = baseDescriptor.withSymbolicTraits(traits)
                let newFont = UIFont(descriptor: descriptor!, size: preserveFontSizes ? (descriptor?.pointSize)! : baseDescriptor.pointSize)
                self.removeAttribute(NSAttributedString.Key.font, range: range)
                self.addAttribute(NSAttributedString.Key.font, value: newFont, range: range)
            }
        }
        endEditing()
    }
}
