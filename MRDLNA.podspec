#
# Be sure to run `pod lib lint MRDLNA.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MRDLNA'
  s.version          = '0.1.1'
  s.summary          = 'DLNA投屏'


  s.description      = <<-DESC
  DLNA投屏,支持各大主流盒子互联网电视.
                       DESC

  s.homepage         = 'https://github.com/MQL9011/MRDLNA'
  
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MQL9011' => '301063915@qq.com' }
  s.source           = { :git => 'https://github.com/MQL9011/MRDLNA.git', :tag => s.version.to_s }
  s.social_media_url = 'http://cocomccree.cn/'

  s.ios.deployment_target = '8.0'

  s.source_files = 'MRDLNA/Classes/ARC/**/*'
  
  # s.resource_bundles = {
  #   'MRDLNA' => ['MRDLNA/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  
  s.libraries = 'icucore', 'c++', 'z', 'xml2'
  
  s.dependency 'CocoaAsyncSocket'
  
  s.xcconfig = {'ENABLE_BITCODE' => 'NO',
      'HEADER_SEARCH_PATHS' => '${SDKROOT}/usr/include/libxml2',
      'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  
  s.subspec 'MRC' do |sp|
      sp.source_files = 'MRDLNA/Classes/MRC/**/*'
      sp.requires_arc = false
  end
end
