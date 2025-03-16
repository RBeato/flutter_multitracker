#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_multitracker.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_multitracker'
  s.version          = '0.0.1'
  s.summary          = 'A multi-track sequencer and sampler plugin for Flutter.'
  s.description      = <<-DESC
A multi-track sequencer and sampler plugin for Flutter supporting SFZ, SF2, and AudioUnit instruments.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '10.0'
  
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SFIZZ_STATIC=1'
  }
  
  # C++ dependencies
  s.libraries = 'c++'
  
  # Include external/sfizz directory
  s.xcconfig = { 
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_multitracker/ios/external/sfizz/include"',
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_multitracker/ios/external/sfizz/include"'
  }
  
  # Add sfizz as a vendored framework
  s.preserve_paths = 'external/**/*'
  
  # Add custom compiler flags
  s.compiler_flags = '-DSFIZZ_STATIC=1'
  
  # Swift versions
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_multitracker_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
