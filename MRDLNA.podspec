#
# Be sure to run `pod lib lint MRDLNA.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MRDLNA'
  s.version          = '0.3.2'
  s.summary          = 'DLNA投屏'


  s.description      = <<-DESC
  DLNA投屏,支持各大主流盒子互联网电视.
  v0.3.2: 增强 getSeekTime / 播放状态与事件回调 / 搜索起停回调 / volume 属性；回调命名 dlnaSearchDidStart/Finish、dlna:state:/event:；搜索回调参数统一为 dlna；CLXMLDocument 按 libxml2 xmlEncodeSpecialChars 规则转义（不再依赖 xml2/GData）；播放回调主线程；搜索 Start/Finish 成对且失败终态必 Finish（bind/发送/异常关闭/主动 stop）.
  v0.3.1: 修复XML解析问题(issue #43), 修复iOS16+设备搜索问题(issue #33/#34), 增加本地网络权限支持, 增强错误处理和日志输出.
                       DESC

  s.homepage         = 'https://github.com/smallgirl/MRDLNA'
  
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MQL9011' => '301063915@qq.com' }
  s.source           = { :git => 'https://github.com/smallgirl/MRDLNA.git', :tag => s.version.to_s }
  s.social_media_url = 'https://github.com/smallgirl'

  s.ios.deployment_target = '12.0'

  s.source_files = 'MRDLNA/Classes/ARC/**/*'
  
  s.public_header_files = 'MRDLNA/Classes/ARC/**/*.h'
  
  s.libraries = 'icucore', 'c++', 'z'
  
  s.dependency 'CocoaAsyncSocket'
  
  s.xcconfig = {'ENABLE_BITCODE' => 'NO',
      'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
