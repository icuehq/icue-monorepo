#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint icue_face_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'icue_face_sdk'
  s.version          = '0.2.0'
  s.summary          = 'On-device face detection and MobileFaceNet recognition for iOS.'
  s.description      = <<-DESC
On-device face detection and MobileFaceNet recognition for iOS applications using LiteRT and ML Kit.
                       DESC
  s.homepage         = 'https://icue.school'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'iCue' => 'support@icue.school' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resources        = 'Assets/**/*'
  s.dependency 'Flutter'
  s.dependency 'TensorFlowLiteSwift', '~> 2.14.0'
  s.dependency 'GoogleMLKit/FaceDetection', '~> 6.0.0'
  s.platform         = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
