import UIKit

struct Styles {

	static let colorTint = colorGray

    static let colorYellow = UIColor(hex:0xFEC800)
    static let colorGreen = UIColor(hex:0x00D266)
    static let colorGray = UIColor(hex:0x4F5B68)
    static let colorGrayLight = UIColor(hex:0xA3A9AF)  
    static let colorRed = UIColor(hex:0xE5006A)
    static let colorBlue = UIColor(hex:0x00C8C6)
    static let colorWhite = UIColor(hex:0xFFFFFF)
    
    static let regularFontName = "Roboto-Regular"
    static let mediumFontName = "Roboto-Medium"
    static let lightFontName = "Roboto-Light"
    static let italicFontName = "Roboto-Italic"
    static let boldFontName = "Roboto-Bold"
    
    static func defaultBoldFont(size: CGFloat) -> UIFont {
        return UIFont(name: boldFontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }
    
    static func defaultRegularFont(size: CGFloat) -> UIFont {
        return UIFont(name: regularFontName, size: size) ?? UIFont.systemFont(ofSize: size)
    }
    
    static func setupGlobalFont() {
        //global Appearance settings
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: defaultBoldFont(size: 17)], for: .normal)
        UINavigationBar.appearance().titleTextAttributes = [.font: defaultBoldFont(size: 17)]
        UITextField.appearance().substituteFontName = regularFontName
        UILabel.appearance().substituteFontName = regularFontName
        UILabel.appearance().substituteFontNameBold = boldFontName
        UILabel.appearance().adjustsFontForContentSizeCategory = true
    }
}

extension UILabel {
    @objc var isBoldFont: Bool {
        get { let fontName = self.font!.fontName
            return fontName.contains("-Bd") || fontName.contains("Medium") || fontName.contains("Bold") }
    }
    @objc var substituteFontName : String {
        get { return self.font.fontName }
        set { if !isBoldFont { self.font = UIFont(name: newValue, size: self.font!.pointSize) } }
    }
    @objc var substituteFontNameBold : String {
        get { return self.font.fontName }
        set { if isBoldFont { self.font = UIFont(name: newValue, size: self.font!.pointSize) } }
    }
}
extension UITextField {
    @objc var substituteFontName : String {
        get { return self.font!.fontName }
        set { self.font = UIFont(name: newValue, size: self.font!.pointSize) }
    }
}
