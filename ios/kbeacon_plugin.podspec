#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint kbeacon_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'kbeacon_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for KBeacon and ESP provisioning.'
  s.description      = <<-DESC
    A Flutter plugin for interacting with KBeacon devices and ESP provisioning using BLE.
  DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{swift, m, h}' # Include Swift and Objective-C files if any
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.1'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' 
  }

  # Specify the Swift version
  s.swift_version     = '5.0'

  # Add dependencies
  s.dependency 'kbeaconlib2', '~> 1.1.8' # Ensure this is the correct pod name and version
  s.dependency 'ESPProvision', '~> 3.0.2' # Ensure this is the correct pod name and version
  s.dependency 'EventBusSwift', '~> 0.2.1' # Add EventBusSwift for event handling

  # Uncomment if you have resource bundles
  # s.resource_bundles = {'kbeacon_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
