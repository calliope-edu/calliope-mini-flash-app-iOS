inhibit_all_warnings!

platform :ios, '12.0'

pod 'TPKeyboardAvoiding'
pod 'SnapKit'
pod 'iOSDFULibrary'
pod 'UICircularProgressRing'
pod 'DeepDiff'
pod 'Highlightr'

target 'Calliope App'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
