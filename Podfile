platform :ios, '16.6'

target 'Calliope App' do

  use_frameworks!
  
  pod 'iOSDFULibrary'
  pod 'GRDB.swift', '~> 6.24'

  target 'Calliope AppTests' do
    inherit! :search_paths
  end

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.6'
      end
    end
  end
end
