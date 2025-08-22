# MRDLNA

[![iOS](https://img.shields.io/badge/platform-iOS-blue.svg)](https://developer.apple.com/ios/)
[![CocoaPods](https://img.shields.io/badge/install-CocoaPods-orange.svg)](https://cocoapods.org/pods/MRDLNA)
[![Objective-C](https://img.shields.io/badge/language-ObjC-brightgreen.svg)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/cocoapods/v/MRDLNA.svg)](https://cocoapods.org/pods/MRDLNA)

## 📖 Overview | 概览

**English**: A powerful iOS DLNA casting library that enables seamless media streaming from iOS devices to DLNA-enabled devices like smart TVs, set-top boxes, and media players. Supports all major TV brands including Xiaomi, Huawei, LeTV, China Mobile STBs, and more.

**中文**: 强大的iOS DLNA投屏库，支持从iOS设备向智能电视、机顶盒等DLNA设备投屏媒体内容。兼容小米、华为、乐视、移动魔百盒等各大主流品牌。

## ✨ Features | 功能特性

### 🎯 Core Features | 核心功能
- [x] **Device Discovery** | 设备搜索 - Automatically discover DLNA devices on the network
- [x] **Media Streaming** | 媒体投屏 - Stream videos, audio, and images
- [x] **Playback Control** | 播放控制 - Play, pause, stop, seek, volume control
- [x] **Multi-format Support** | 多格式支持 - Video (MP4, AVI, MKV), Audio (MP3, AAC), Images (JPG, PNG)
- [x] **Custom Metadata** | 自定义元数据 - Set custom title and creator information
- [x] **Thread Safety** | 线程安全 - Optimized for concurrent operations
- [x] **Error Handling** | 错误处理 - Robust error handling and recovery

### 📱 Supported Devices | 支持设备
- Smart TVs (Samsung, LG, Sony, etc.) | 智能电视
- Set-top Boxes (Xiaomi, Huawei, LeTV) | 机顶盒
- Media Players | 媒体播放器
- Any DLNA/UPnP compatible device | 任何DLNA/UPnP兼容设备

## 🚀 Installation | 安装

### CocoaPods
```ruby
pod 'MRDLNA', '~> 0.3.0'
```

### Manual Installation | 手动安装
1. Download the source code | 下载源码
2. Drag `MRDLNA` folder into your project | 将MRDLNA文件夹拖入项目
3. Add required frameworks | 添加必要框架

## 📋 Requirements | 系统要求

- iOS 12.0+ 
- Xcode 11.0+
- Objective-C or Swift

## 🛠 Usage | 使用方法

### 1. Import the Library | 导入库
```objc
#import <MRDLNA/MRDLNA.h>
```

### 2. Device Discovery | 设备搜索

```objc
@interface YourViewController : UIViewController <DLNADelegate>
@property(nonatomic, strong) MRDLNA *dlnaManager;
@property(nonatomic, strong) NSArray *discoveredDevices;
@end

@implementation YourViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize DLNA manager | 初始化DLNA管理器
    self.dlnaManager = [MRDLNA sharedMRDLNAManager];
    self.dlnaManager.delegate = self;
    self.dlnaManager.searchTime = 10; // Search for 10 seconds | 搜索10秒
    
    // Start device discovery | 开始搜索设备
    [self.dlnaManager startSearch];
}

#pragma mark - DLNADelegate

- (void)searchDLNAResult:(NSArray *)devicesArray {
    NSLog(@"Found %lu DLNA devices", (unsigned long)devicesArray.count);
    self.discoveredDevices = devicesArray;
    // Update your UI here | 在此更新UI
}

- (void)dlnaStartPlay {
    NSLog(@"DLNA streaming started successfully");
    // Handle successful streaming | 处理投屏成功
}

@end
```

### 3. Media Streaming | 媒体投屏

```objc
// Select a device from discovered devices | 从发现的设备中选择一个
CLUPnPDevice *selectedDevice = self.discoveredDevices.firstObject;
self.dlnaManager.device = selectedDevice;

// Set media URL | 设置媒体URL
NSString *mediaURL = @"http://example.com/video.mp4";
self.dlnaManager.playUrl = mediaURL;

// Basic streaming | 基础投屏
[self.dlnaManager startDLNA];

// OR Enhanced streaming with metadata | 或使用增强的元数据投屏
[self.dlnaManager.render setAVTransportURL:mediaURL 
                                    title:@"My Video Title" 
                                  creator:@"Creator Name"];
```

### 4. Playback Control | 播放控制

```objc
// Play/Pause toggle | 播放/暂停切换
- (IBAction)togglePlayPause:(id)sender {
    if (self.isPlaying) {
        [self.dlnaManager dlnaPause];
    } else {
        [self.dlnaManager dlnaPlay];
    }
    self.isPlaying = !self.isPlaying;
}

// Volume control (0-100) | 音量控制 (0-100)
- (IBAction)volumeChanged:(UISlider *)sender {
    NSString *volume = [NSString stringWithFormat:@"%.0f", sender.value];
    [self.dlnaManager volumeChanged:volume];
}

// Seek to position (in seconds) | 跳转到指定位置 (秒)
- (IBAction)seekToPosition:(UISlider *)sender {
    NSInteger seconds = (NSInteger)sender.value;
    [self.dlnaManager seekChanged:seconds];
}

// Stop and disconnect | 停止并断开连接
- (IBAction)stopStreaming:(id)sender {
    [self.dlnaManager endDLNA];
}

// Switch to different media | 切换到不同媒体
- (IBAction)playNextVideo:(id)sender {
    NSString *nextVideoURL = @"http://example.com/next-video.mp4";
    [self.dlnaManager playTheURL:nextVideoURL];
}
```

### 5. Advanced Usage | 高级用法

#### Custom Media Types | 自定义媒体类型
```objc
// The library automatically detects media type based on URL extension
// 库会根据URL扩展名自动检测媒体类型

// Video formats: .mp4, .avi, .mkv, .mov, .wmv, .flv
// Audio formats: .mp3, .wav, .flac, .aac, .ogg  
// Image formats: .jpg, .jpeg, .png, .gif, .bmp

NSString *audioURL = @"http://example.com/music.mp3";
[self.dlnaManager.render setAVTransportURL:audioURL 
                                    title:@"Beautiful Song" 
                                  creator:@"Artist Name"];
```

#### Error Handling | 错误处理
```objc
// Implement delegate method for search errors | 实现搜索错误的代理方法
- (void)upnpSearchErrorWithError:(NSError *)error {
    NSLog(@"DLNA search failed: %@", error.localizedDescription);
    // Handle search failure | 处理搜索失败
}

// Alternative start method with error recovery | 带错误恢复的启动方法
[self.dlnaManager startDLNAAfterStop]; // This stops current session first
```

## 🔧 Configuration | 配置

### Network Settings | 网络设置
```objc
// Adjust search timeout | 调整搜索超时时间
self.dlnaManager.searchTime = 15; // Default is 5 seconds | 默认5秒

// The library uses these default network settings:
// 库使用以下默认网络设置:
// - Multicast address: 239.255.255.250
// - SSDP port: 1900
// - HTTP timeout: 10 seconds
```

## 📱 Demo Project | 示例项目

The repository includes a comprehensive demo project showing:
本仓库包含完整的示例项目，展示：

- Device discovery UI | 设备搜索界面
- Media streaming controls | 媒体投屏控制
- Volume and seek controls | 音量和进度控制
- Error handling examples | 错误处理示例

To run the demo | 运行示例：
```bash
cd Example
pod install
open MRDLNA.xcworkspace
```

## 🐛 Troubleshooting | 故障排除

### Common Issues | 常见问题

**Q: No devices found | 找不到设备**
- Ensure devices are on the same WiFi network | 确保设备在同一WiFi网络
- Check if DLNA is enabled on target device | 检查目标设备是否启用DLNA
- Verify firewall settings | 验证防火墙设置

**Q: Streaming fails | 投屏失败**
- Verify media URL is accessible | 验证媒体URL可访问
- Check media format compatibility | 检查媒体格式兼容性
- Try using `startDLNAAfterStop` method | 尝试使用`startDLNAAfterStop`方法

**Q: Controls not working | 控制失效**
- Ensure device supports transport controls | 确保设备支持传输控制
- Check network connectivity | 检查网络连接
- Restart the streaming session | 重启投屏会话

## 🔄 Version History | 版本历史

### v0.3.0 (Latest | 最新)
- ✨ Enhanced DIDL-Lite with multi-media type support | 增强DIDL-Lite多媒体类型支持
- 🐛 Fixed spelling errors and type issues | 修复拼写错误和类型问题
- 🔒 Improved thread safety | 改进线程安全性
- ⚡ Better error handling and network timeouts | 更好的错误处理和网络超时
- 🎵 Added custom media metadata API | 新增自定义媒体元数据API

### v0.2.0
- 🔄 Replaced GDataXMLNode with CLXMLParser | 用CLXMLParser替换GDataXMLNode
- 📱 Updated for modern iOS versions | 更新支持现代iOS版本

## 🤝 Contributing | 贡献

We welcome contributions! Please feel free to submit issues and pull requests.
欢迎贡献代码！请随时提交问题和拉取请求。

1. Fork the repository | 复刻仓库
2. Create your feature branch | 创建功能分支
3. Commit your changes | 提交更改
4. Push to the branch | 推送到分支
5. Open a Pull Request | 创建拉取请求

## 📄 License | 许可证

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
本项目基于MIT许可证 - 详见[LICENSE](LICENSE)文件。

## 🙏 Acknowledgments | 致谢

- UPnP Forum for DLNA specifications | UPnP论坛提供的DLNA规范
- CocoaAsyncSocket for networking support | CocoaAsyncSocket提供网络支持
- All contributors and users | 所有贡献者和用户

## 📞 Support | 支持

- 🐛 **Issues**: [GitHub Issues](https://github.com/MQL9011/MRDLNA/issues)
- 📧 **Email**: 301063915@qq.com
- 🌐 **CocoaPods**: [MRDLNA on CocoaPods](https://cocoapods.org/pods/MRDLNA)

---

**Star ⭐ this repository if it helped you! | 如果这个库对你有帮助，请给个星星！**