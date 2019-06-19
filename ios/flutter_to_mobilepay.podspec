#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_to_mobilepay'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin to integrate with MobilePay'
  s.description      = 'Flutter plugin to integrate with MobilePay'
  s.homepage         = 'https://github.com/semlette/flutter_to_mobilepay'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Andi Robin Halgren Semler' => 'andirobinsemler@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'MobilePay-AppSwitch-SDK'
  s.static_framework = true

  s.ios.deployment_target = '8.0'
end

