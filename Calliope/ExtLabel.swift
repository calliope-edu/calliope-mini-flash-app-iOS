import UIKit

class Label: UILabel {

//    override func drawText(in rect: CGRect) {
//        if let stringText = text {
//            let stringTextAsNSString = stringText as NSString
//            let labelStringSize = stringTextAsNSString.boundingRect(
//                with: CGSize(width: self.frame.width, height: CGFloat.greatestFiniteMagnitude),
//                options: NSStringDrawingOptions.usesLineFragmentOrigin,
//                attributes: [NSAttributedStringKey.font: font],
//                context: nil).size
//            super.drawText(in: CGRect(x: 0, y: 0, width: self.frame.width, height: ceil(labelStringSize.height)))
//        } else {
//            super.drawText(in: rect)
//        }
//    }

//    override func layoutSubviews() {
//        preferredMaxLayoutWidth = frame.size.width
//        super.layoutSubviews()
//    }

//    override var bounds: CGRect {
//        didSet {
//            if (bounds.size.width != preferredMaxLayoutWidth) {
//                preferredMaxLayoutWidth = bounds.size.width;
//                setNeedsUpdateConstraints()
//            }
//        }
//    }

//    override var bounds: CGRect {
//        get {
//            return super.bounds
//        }
//        set {
//            super.bounds = newValue
//            if (self.preferredMaxLayoutWidth != super.bounds.size.width) {
//                self.preferredMaxLayoutWidth = super.bounds.size.width
//                self.setNeedsUpdateConstraints()
//            }
//        }
//    }

//    override func updateConstraints() {
//        if(self.preferredMaxLayoutWidth != self.bounds.size.width) {
//            self.preferredMaxLayoutWidth = self.bounds.size.width
//        }
//        super.updateConstraints()
//    }
}
