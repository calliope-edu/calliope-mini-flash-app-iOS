platform :ios, '13.0'

target 'Calliope App' do

  use_frameworks!
  
  pod 'TPKeyboardAvoiding'
  pod 'SnapKit'
  pod 'iOSDFULibrary'
  pod 'UICircularProgressRing'
  pod 'DeepDiff'
  pod 'Highlightr'
  ## MDC
  pod 'MaterialComponents'
  ## ZipArchive
  pod 'SSZipArchive', '2.1.1'
  ## SnapKit
  pod 'SnapKit'
  pod 'SQLite.swift', '~> 0.14.0'
  pod 'GRDB.swift', '~> 6.24'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end
