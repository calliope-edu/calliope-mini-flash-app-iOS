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


    static func defaultFont(size:CGFloat) -> UIFont {
        return UIFont(name: "RobotoMono-Bold", size: size) ?? UIFont.systemFont(ofSize: size)
    }

    static let fontText = defaultFont(size:range(15...35))
    

    static func apply() {

		UIWindow.appearance().tintColor = colorTint
		
		for window in UIApplication.shared.windows {
			window.tintColor = colorTint
		}

		// MARK: Navigation Bar
        UINavigationBar.appearance().barTintColor = colorWhite
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().titleTextAttributes = [
            NSAttributedString.Key.font: defaultFont(size: range(15...25)),
        ]

        // MARK: UIBarButtonItem
        UIBarButtonItem.appearance().setTitleTextAttributes([
            NSAttributedString.Key.font: defaultFont(size: range(15...25)),
        ], for: .normal)

    }
}
