platform :ios, '10.0'
use_frameworks!
inhibit_all_warnings!

pod 'SnapKit', '~> 3.2'
pod 'iOSDFULibrary', '~> 3.2.1'

target 'Calliope'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.2'
    end
  end
end


# pod 'HydraAsync' #, '~>0.9.9'
# pod 'SwiftyBluetooth'
# pod 'LGBluetooth', '~> 1.1.5'
# pod 'RxBluetoothKit', '~> 3.0'
# pod 'RxSwift', '~> 3.5'
# pod 'NSObject+Rx', '~> 2.3'
# pod 'RxDataSources', '~> 1.0'

# pod 'SwiftyUserDefaults', '~> 3.0'
# pod 'Alamofire', '~> 4.5'
# pod 'AlamofireImage', '~> 3.2'
# pod 'KeychainAccess', '~> 3.0'
# pod 'RazzleDazzle', '~> 0.1'
# pod 'SwiftyBeaver', '~> 1.3'
# pod 'ReachabilitySwift', '~> 3'
# pod 'HockeySDK', '~> 4.1'
# pod 'Unbox', '~> 2.5'
# pod 'Flurry-iOS-SDK/FlurrySDK', '~> 8.1'
# pod 'AdobeMobileSDK', '~> 4.13'
# pod 'GoogleAnalytics', '~> 3.17'

# def test_pods
#   pod 'Quick', '~> 1.1'
#   pod 'Nimble', '~> 7.0'
# end

# target 'UnitTests' do
#   inherit! :search_paths
#   test_pods
# end

# target 'UITests' do
#   inherit! :search_paths
#   test_pods
# end

