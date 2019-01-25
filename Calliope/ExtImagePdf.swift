import UIKit

// based on code from Roman Bambura

extension UIImage {

    fileprivate static var _imagesCache: NSCache<AnyObject, AnyObject>?
    fileprivate static var _shouldCache: Bool = false
    fileprivate static var _shouldCacheOnDisk: Bool = true
    fileprivate static var _assetName: String?
    fileprivate static var _resourceName: String?


    static var cachedAssetsDirectory: String{
        get{
            return "CachedAssets"
        }
    }

    static var resourceName: String?{

        set{
            _resourceName = newValue
            _assetName = newValue!.components(separatedBy: ".")[0]
        }
        get{
            return _resourceName
        }
    }

    static var assetName: String? {
        set{
            _assetName = newValue
            _resourceName = _assetName! + ".pdf"
        }
        get{
            return _assetName
        }
    }


    static var shouldCacheInMemory:Bool{

        set{
            _shouldCache = newValue

            if( _shouldCache && _imagesCache == nil)
            {
                _imagesCache = NSCache()
            }
        }
        get{
            return _shouldCache
        }
    }

    static var shouldCacheOnDisk: Bool {

        set{
            _shouldCacheOnDisk = newValue;
        }
        get{
            return _shouldCacheOnDisk
        }

    }


    // Mark: Public Func

    class func pdfAssetNamed(_ name: String) -> UIImage?{

        assetName = name

        return self.originalSizeImageWithPDFNamed(resourceName!)
    }

    class func pdfAssetWithContentsOfFile(_ path: String) -> UIImage?{
        return self.originalSizeImageWithPDFURL( URL(fileURLWithPath: path))
    }

    class func screenScale() -> CGFloat{
        return UIScreen.main.scale
    }


    // Mark: Get UIImage With PDF Name Without Extension

    // Mark: UIImage With Size
    class func imageWithPDFNamed(_ name: String, size:CGSize) -> UIImage? {

        assetName = name

        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(resourceName)!, size:size)
    }

    // Mark:  UIImage With Width
    class func imageWithPDFNamed(_ name: String,  width:CGFloat) -> UIImage?{

        assetName = name

        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(resourceName), width: width)
    }

    // Mark:  UIImage With Height
    class func imageWithPDFNamed(_ name: String,  height:CGFloat) -> UIImage?{

        assetName = name

        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(resourceName), height: height)
    }

    // Mark:  UIImage  Size To Fit
    class func imageWithPDFNamed(_ name: String, fitSize size: CGSize) -> UIImage? {

        assetName = name

        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(_resourceName), fitSize:size)
    }



    // Mark: Resource name
    // Size
    fileprivate class func imageWithPDFNamed(_ name: String, size: CGSize,  page: Int) -> UIImage? {
        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(resourceName!), size:size, page:page)
    }

    // Width
    fileprivate class func imageWithPDFNamed(_ name: String,  width:CGFloat,  page: Int) -> UIImage?{
        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(resourceName), width: width, page: page)
    }

    // Height
    fileprivate class func imageWithPDFNamed( _ name: String,  height:CGFloat,  page: Int) -> UIImage?{
        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(resourceName), height : height, page: page)
    }

    // Fit
    fileprivate class func imageWithPDFNamed(_ name: String, fitSize size: CGSize,  page: Int) -> UIImage? {
        return self.imageWithPDFURL( PDFResourceHelper.resourceURLForName(name), fitSize:size, page:page)
    }

    // Original Size
    fileprivate class func originalSizeImageWithPDFNamed(_ resourceName: String,  page: Int) -> UIImage?{
        return self.originalSizeImageWithPDFURL( PDFResourceHelper.resourceURLForName( resourceName ), page:page)
    }

    fileprivate class func originalSizeImageWithPDFNamed(_ resourceName: String) -> UIImage?{
        return self.originalSizeImageWithPDFURL( PDFResourceHelper.resourceURLForName( resourceName) )
    }


    // Mark: Resource Data
    class func originalSizeImageWithPDFData( _ data: Data ) -> UIImage? {
        let mediaRect: CGRect = PDFResourceHelper.mediaRectForData(data, page:1)
        return self.imageWithPDFData(data, size:mediaRect.size, page:1 )
    }

    class func imageWithPDFData(_ data: Data,  width:CGFloat) -> UIImage?{
        return self.imageWithPDFData(data, width:width, page:1)
    }

    class func imageWithPDFData(_ data: Data?,  width:CGFloat,  page:Int) -> UIImage?{

        if ( data == nil ){
          return UIImage()
        }

        let mediaRect: CGRect = PDFResourceHelper.mediaRectForData(data, page:page)
        let aspectRatio: CGFloat = mediaRect.size.width / mediaRect.size.height
        let size: CGSize = CGSize( width: width, height: ceil( width / aspectRatio ))

        return self.imageWithPDFData(data, size:size, page:page)
    }


    class func imageWithPDFData(_ data: Data?,  height:CGFloat) -> UIImage? {
        return self.imageWithPDFData(data, height:height, page:1)
    }

    class func imageWithPDFData(_ data: Data?,  height:CGFloat,  page:Int) -> UIImage?{

        if ( data == nil ){
            return UIImage()
        }

        let mediaRect: CGRect = PDFResourceHelper.mediaRectForData(data, page:page)
        let aspectRatio: CGFloat = mediaRect.size.width / mediaRect.size.height
        let size: CGSize = CGSize( width: ceil( height / aspectRatio ), height: height)

        return self.imageWithPDFData(data, size:size, page:page)
    }

    class func imageWithPDFData( _ data: Data?, fitSize size:CGSize) -> UIImage? {
        return self.imageWithPDFData(data, fitSize:size, page:1)
    }

    class func imageWithPDFData(_ data: Data?, fitSize size: CGSize,  page: Int) -> UIImage? {
        return self.imageWithPDFData(data, size:size, page:page, preserveAspectRatio:true)
    }

    class func imageWithPDFData(_ data: Data?,  size: CGSize ) -> UIImage? {
        return self.imageWithPDFData(data, size:size, page:1)
    }

    class func imageWithPDFData( _ data: Data?,  size: CGSize,  page: Int) -> UIImage? {
        return self.imageWithPDFData(data, size:size, page:page, preserveAspectRatio:false)
    }

    class func imageWithPDFData( _ data: Data?,  size: CGSize,  page: Int, preserveAspectRatio: Bool) -> UIImage?{

        if(data == nil || size.equalTo(CGSize.zero) || page == 0){
            return UIImage();
        }

        var pdfImage: UIImage?

        let cacheFilename: String = self.cacheFileNameForResourceNamed(self.assetName!, size: size)
        let cacheFilePath: String = self.cacheFilePathForResourceNamed(cacheFilename)

        if(_shouldCacheOnDisk && FileManager.default.fileExists(atPath: cacheFilePath))
        {
            pdfImage = UIImage(contentsOfFile: cacheFilePath)
        }
        else
        {

            let screenScale: CGFloat = UIScreen.main.scale
            let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
            let ctx: CGContext = CGContext(data: nil, width: Int(size.width * screenScale), height: Int(size.height * screenScale), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo().rawValue)!
            ctx.scaleBy(x: screenScale, y: screenScale);

            PDFResourceHelper.renderIntoContext(ctx, url:nil, data:data, size:size, page:page, preserveAspectRatio:preserveAspectRatio)
            if let image: CGImage = ctx.makeImage(){
                pdfImage =  UIImage(cgImage: image, scale: screenScale, orientation: UIImage.Orientation.up)
            }

            if(_shouldCacheOnDisk)
            {
                if let data = pdfImage!.pngData( ) {
                    try? data.write(to: URL(fileURLWithPath: cacheFilePath), options: [])
                }
            }
        }

        if (pdfImage != nil && _shouldCache)
        {
            _imagesCache?.setObject(pdfImage!, forKey: cacheFilename as AnyObject)
        }

        return pdfImage;
    }

    // Mark: Resource URLs

    class func imageWithPDFURL(_ URL: Foundation.URL?,  size: CGSize,  page:Int) -> UIImage?{
        return self.imageWithPDFURL(URL, size:size, page:page, preserveAspectRatio:false)
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?,  size:CGSize,  page: Int, preserveAspectRatio:Bool) -> UIImage? {

        if(URL == nil || size.equalTo(CGSize.zero) || page == 0){
            return nil
        }

        var pdfImage: UIImage?

        let cacheFilename: String = self.cacheFileNameForResourceNamed(self.assetName!, size: size)
        let cacheFilePath: String = self.cacheFilePathForResourceNamed(cacheFilename)

        if (_shouldCache)
        {
            pdfImage = _imagesCache!.object(forKey: cacheFilename as AnyObject) as? UIImage

            if (pdfImage != nil) {
                return pdfImage
            }
        }

        if(_shouldCacheOnDisk && FileManager.default.fileExists(atPath: cacheFilePath))
        {
            pdfImage = UIImage(contentsOfFile: cacheFilePath)

        }
        else
        {

            let screenScale: CGFloat = UIScreen.main.scale
            let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
            let ctx: CGContext = CGContext(data: nil, width: Int(size.width * screenScale), height: Int(size.height * screenScale), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo().rawValue)!
            ctx.scaleBy(x: screenScale, y: screenScale);

            PDFResourceHelper.renderIntoContext(ctx, url:URL, data:nil, size:size, page:page, preserveAspectRatio:preserveAspectRatio)
            if let image: CGImage = ctx.makeImage(){
                pdfImage =  UIImage(cgImage: image, scale: screenScale, orientation: UIImage.Orientation.up)
            }

            if(_shouldCacheOnDisk)
            {
                if let data = pdfImage!.pngData( ) {
                    try? data.write(to: Foundation.URL(fileURLWithPath: cacheFilePath), options: [])
                }
            }
        }

        if (pdfImage != nil && _shouldCache)
        {
            _imagesCache?.setObject(pdfImage!, forKey: cacheFilename as AnyObject)
        }

        return pdfImage;
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?,  size: CGSize) -> UIImage?{
        return self.imageWithPDFURL(URL, size:size, page:1, preserveAspectRatio:false)
    }

    fileprivate class func imageWithPDFURL(_ URL: Foundation.URL?, fitSize size: CGSize,  page: Int) -> UIImage?{
        return self.imageWithPDFURL(URL, size:size, page:page, preserveAspectRatio:true)
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?, fitSize size: CGSize) -> UIImage?{
        return self.imageWithPDFURL(URL, fitSize:size, page:1)
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?,  width: CGFloat,  page: Int) -> UIImage?{

        let mediaRect: CGRect = PDFResourceHelper.mediaRectForURL(URL, page:page)
        let aspectRatio: CGFloat = mediaRect.size.width / mediaRect.size.height;

        let size: CGSize = CGSize( width: width, height: ceil( width / aspectRatio ));

        return self.imageWithPDFURL(URL, size:size, page:page)
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?,  width: CGFloat) -> UIImage? {
        return self.imageWithPDFURL(URL, width:width, page:1)
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?,  height: CGFloat,  page: Int) -> UIImage? {

        if ( URL == nil ){
            return nil
        }

        let mediaRect: CGRect = PDFResourceHelper.mediaRectForURL(URL, page:page)
        let aspectRatio: CGFloat = mediaRect.size.width / mediaRect.size.height;
        let size: CGSize = CGSize( width: ceil( height * aspectRatio ), height: height );

        return self.imageWithPDFURL(URL, size:size, page:page)
    }

    class func imageWithPDFURL(_ URL: Foundation.URL?,  height: CGFloat) -> UIImage? {
        return self.imageWithPDFURL(URL, height:height, page:1)
    }

    class func originalSizeImageWithPDFURL( _ URL: Foundation.URL?,  page: Int) -> UIImage? {

        if ( URL == nil ){
            return nil
        }

        let mediaRect: CGRect = PDFResourceHelper.mediaRectForURL(URL, page:page)

        return self.imageWithPDFURL(URL, size:mediaRect.size, page:page, preserveAspectRatio:true)
    }

    class func originalSizeImageWithPDFURL(_ URL: Foundation.URL?) -> UIImage? {
        return self.originalSizeImageWithPDFURL(URL, page:1)
    }

    // Mark: Cacheing
    fileprivate class func cacheFileNameForResourceNamed(_ resourceName: String, size: CGSize) -> String{
        return String(format: "%@_%dX%d@%dx",resourceName, Int(size.width), Int(size.height), Int(self.screenScale()) )
    }

    fileprivate class func cacheFilePathForResourceNamed(_ resourceName: String,  size: CGSize) -> String{
        let fileName: String = self.cacheFileNameForResourceNamed(resourceName, size: size)
        return self.cacheFilePathForResourceNamed(fileName)
    }

    fileprivate class func cacheFilePathForResourceNamed(_ cacheResourseName: String) -> String{

        let fileManager: FileManager = FileManager.default
        let documentsDirectoryPath: NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let cacheDirectory = String(format: "%@/%@", documentsDirectoryPath, cachedAssetsDirectory)
        do{
            try  fileManager.createDirectory(atPath: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }catch{
            print ("CACHES DIRECTORY IMAGE+PDF CAN'T BE CREATED!")
        }

        return String(format:"%@/%@.png", cacheDirectory, cacheResourseName)
    }

}


fileprivate class PDFResourceHelper {

    static func resourceURLForName(_ resourceName:String?) -> URL?{

        if let path = Bundle.main.path(forResource: resourceName , ofType: nil){
            return URL(fileURLWithPath:path)
        }
        return nil
    }

    static func mediaRect(_ resourceName: String?) -> CGRect
    {
        return self.mediaRectForURL(self.resourceURLForName(resourceName)!)
    }

    static func mediaRectForURL(_ resourceURL: URL) -> CGRect
    {
        return mediaRectForURL(resourceURL, page:1)
    }




    static func mediaRectForURL(_ resourceURL: URL?,  page: Int)-> CGRect{

        var rect:CGRect = CGRect.null

        if resourceURL != nil
        {
            if let pdf:CGPDFDocument = CGPDFDocument(resourceURL! as CFURL)
            {

                if let page1:CGPDFPage = pdf.page(at: page)
                {

                    rect = page1.getBoxRect(CGPDFBox.cropBox)

                    let rotationAngle = page1.rotationAngle

                    if (rotationAngle == 90 || rotationAngle == 270)
                    {
                        let temp = rect.size.width
                        rect.size.width = rect.size.height
                        rect.size.height = temp
                    }
                }
            }
        }

        return rect;
    }

    static func renderIntoContext(_ ctx: CGContext,  url resourceURL: URL?, data resourceData:Data?, size: CGSize, page:Int, preserveAspectRatio:Bool){

        var document: CGPDFDocument?

        if resourceURL != nil
        {
            document = CGPDFDocument( resourceURL! as CFURL )!
        }
        else if resourceData != nil
        {
            if let provider: CGDataProvider = CGDataProvider( data: resourceData! as CFData )
            {
                document = CGPDFDocument( provider )!
            }
        }

        if let page1: CGPDFPage = document?.page(at: page ){

            let destRect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

            let drawingTransform: CGAffineTransform = page1.getDrawingTransform(CGPDFBox.cropBox, rect: destRect, rotate: 0, preserveAspectRatio: preserveAspectRatio);
            ctx.concatenate(drawingTransform)
            ctx.drawPDFPage(page1 )
        }
    }

    static func mediaRectForData(_ data: Data?,  page: Int) -> CGRect{

        var rect:CGRect = CGRect.null

        if data != nil
        {
            if let provider:CGDataProvider = CGDataProvider( data: data! as CFData )
            {

                if let document:CGPDFDocument = CGPDFDocument( provider ){

                    if let page1:CGPDFPage = document.page(at: page )
                    {

                        rect = page1.getBoxRect(CGPDFBox.cropBox )

                        let rotationAngle = page1.rotationAngle

                        if (rotationAngle == 90 || rotationAngle == 270)
                        {
                            let temp = rect.size.width
                            rect.size.width = rect.size.height
                            rect.size.height = temp
                        }
                    }
                }
            }
        }

        return rect;
    }
}
