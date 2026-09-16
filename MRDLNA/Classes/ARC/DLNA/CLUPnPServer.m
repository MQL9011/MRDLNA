//
//  CLUPnPServer.m
//  DLNA_UPnP
//
//  Created by ClaudeLi on 2017/7/31.
//  Copyright © 2017年 ClaudeLi. All rights reserved.
//

#import "CLUPnP.h"
#import "CLUPnPServer.h"
#import "GCDAsyncUdpSocket.h"
#import "CLXMLParser.h"

@interface CLUPnPServer ()<GCDAsyncUdpSocketDelegate>

@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;

// key: usn(uuid) string,  value: device
@property (nonatomic, strong) NSMutableDictionary<NSString *, CLUPnPDevice *> *deviceDictionary;

#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t                          queue;
#else
@property (nonatomic, assign) dispatch_queue_t                          queue;
#endif

@property (nonatomic, assign) BOOL receiveDevice;
@property (nonatomic, assign) NSInteger retryCount;
/// 本轮搜索是否尚未结束（保证 didStopSearch 与 start 成对、且同一轮只回调一次）
@property (nonatomic, assign) BOOL searchSessionActive;
@property (nonatomic, assign) NSInteger searchGeneration;
/// 重试前主动 close，避免 udpSocketDidClose 误结束本轮
@property (nonatomic, assign) BOOL closingForRetry;

@end

@implementation CLUPnPServer

@synthesize delegate = _delegate;

@synthesize deviceDictionary = _deviceDictionary;

- (void)dealloc{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_queue);
#endif
}

+ (instancetype)shareServer{
    static CLUPnPServer *server;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        server = [[self alloc] init];
    });
    return server;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.receiveDevice = YES;
        _queue = dispatch_queue_create("com.mccree.upnp.dlna", DISPATCH_QUEUE_SERIAL);
        _deviceDictionary = [NSMutableDictionary dictionary];
        [self setupSocket];
    }
    return self;
}

- (void)setupSocket{
    _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    // 强制使用 IPv4，因为 SSDP 多播地址 239.255.255.250 是 IPv4 地址
    [_udpSocket setIPv4Enabled:YES];
    [_udpSocket setIPv6Enabled:NO];
}

- (NSString *)getSearchString{
    return [NSString stringWithFormat:@"M-SEARCH * HTTP/1.1\r\nHOST: %@:%d\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: %@\r\nUSER-AGENT: iOS UPnP/1.1 mccree/1.0\r\n\r\n", ssdpAddres, ssdpPort, serviceType_AVTransport];
}

- (BOOL)beginSearchSessionIfNeeded {
    @synchronized (self) {
        if (self.searchSessionActive) {
            self.closingForRetry = NO;
            return NO;
        }
        self.searchSessionActive = YES;
        self.searchGeneration += 1;
        self.retryCount = 0;
        self.closingForRetry = NO;
        return YES;
    }
}

- (void)start{
    NSError *error = nil;
    
    // 检测运行环境
#if TARGET_OS_SIMULATOR
    NSLog(@"[MRDLNA] ⚠️ 检测到模拟器环境，DLNA 搜索可能无法正常工作");
    NSLog(@"[MRDLNA] ⚠️ 请使用真机测试 DLNA 功能");
#endif
    
    BOOL isNewSession = [self beginSearchSessionIfNeeded];
    if (isNewSession) {
        if ([self.delegate respondsToSelector:@selector(didStartSearch)]) {
            [self.delegate didStartSearch];
        }
    }
    
    // 如果 socket 已关闭或未初始化，重新创建
    if (!_udpSocket || _udpSocket.isClosed) {
        [self setupSocket];
    }
    
    // 检查 socket 是否已经在运行（已绑定端口）
    // 如果是，直接发送搜索请求
    if (_udpSocket.localPort != 0) {
        NSLog(@"[MRDLNA] Socket already bound to port %d, sending search directly", _udpSocket.localPort);
        [self search];
        return;
    }
    
    // 启用端口复用（iOS 16+ 需要）
    if (![_udpSocket enableReusePort:YES error:&error]) {
        NSLog(@"[MRDLNA] enableReusePort error: %@", error);
        // 继续尝试，某些系统可能不支持
    }
    
    // 启用广播（某些路由器需要）
    if (![_udpSocket enableBroadcast:YES error:&error]) {
        NSLog(@"[MRDLNA] enableBroadcast error: %@", error);
    }
    
    // 绑定到随机端口而不是 SSDP 端口（避免端口冲突）
    // SSDP 响应会发送回我们的端口，不需要绑定到 1900
    if (![_udpSocket bindToPort:0 error:&error]){
        NSLog(@"[MRDLNA] bindToPort error: %@", error);
        [self onError:error];
        [self notifySearchDidStop];
        return;
    }
    
    NSLog(@"[MRDLNA] Socket bound to port %d", _udpSocket.localPort);
    
    if (![_udpSocket beginReceiving:&error])
    {
        NSLog(@"[MRDLNA] beginReceiving error: %@", error);
        [self onError:error];
        [self notifySearchDidStop];
        return;
    }
    
    // 加入多播组以接收 NOTIFY 消息（可选，失败不影响主要功能）
    if (![_udpSocket joinMulticastGroup:ssdpAddres error:&error])
    {
        NSLog(@"[MRDLNA] joinMulticastGroup error: %@", error);
        // 不返回，继续搜索 - 即使加入多播组失败，M-SEARCH 响应仍然可以收到
    }
    
    [self search];
}

- (void)stop{
    [_udpSocket leaveMulticastGroup:ssdpAddres error:nil];
    [_udpSocket close];
    [self notifySearchDidStop];
}

- (void)search{
    // 搜索前先清空设备列表
    [self.deviceDictionary removeAllObjects];
    self.receiveDevice = YES;
    [self onChange];
    
    // 允许单独调 search：同样纳入「开搜必有结束」契约
    if ([self beginSearchSessionIfNeeded]) {
        if ([self.delegate respondsToSelector:@selector(didStartSearch)]) {
            [self.delegate didStartSearch];
        }
    }
    
    if (!_udpSocket || _udpSocket.isClosed) {
        NSLog(@"[MRDLNA] search: socket is closed, cannot send");
        NSError *error = [NSError errorWithDomain:@"MRDLNA" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"UDP socket is closed"}];
        [self onError:error];
        [self notifySearchDidStop];
        return;
    }
    
    NSString *searchString = [self getSearchString];
    NSLog(@"[MRDLNA] 发送 M-SEARCH 到 %@:%d", ssdpAddres, ssdpPort);
    NSLog(@"[MRDLNA] M-SEARCH 内容:\n%@", searchString);
    
    NSData *sendData = [searchString dataUsingEncoding:NSUTF8StringEncoding];
    [_udpSocket sendData:sendData toHost:ssdpAddres port:ssdpPort withTimeout:5 tag:1];
}

- (NSArray<CLUPnPDevice *> *)getDeviceList{
    return self.deviceDictionary.allValues;
}


#pragma mark -- GCDAsyncUdpSocketDelegate --

/// 结束本轮搜索并通知上层（成功超时 / 任一失败终态都要走；同一轮幂等一次）
- (void)notifySearchDidStop {
    @synchronized (self) {
        if (!self.searchSessionActive) {
            return;
        }
        self.searchSessionActive = NO;
        self.receiveDevice = NO;
        self.closingForRetry = NO;
    }
    NSLog(@"[MRDLNA] 搜索结束，找到 %lu 个设备", (unsigned long)self.deviceDictionary.count);
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didStopSearch)]) {
            [self.delegate didStopSearch];
        }
    });
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag{
    NSLog(@"[MRDLNA] M-SEARCH 发送成功，等待设备响应...");
    __weak typeof (self) weakSelf = self;
    NSInteger generation;
    NSInteger searchTime;
    @synchronized (self) {
        generation = self.searchGeneration;
        searchTime = self.searchTime;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(searchTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        @synchronized (strongSelf) {
            // 过期 timer 不得结束新一轮搜索
            if (strongSelf.searchGeneration != generation) { return; }
        }
        [strongSelf notifySearchDidStop];
    });
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error{
    NSLog(@"[MRDLNA] M-SEARCH 发送失败: %@", error);
    
    // No route to host：重试通常无效，直接结束本轮，让上层结束「搜索中」或自行再搜
    if (error.code == 65) {
        NSLog(@"[MRDLNA] ⚠️ 'No route to host' 错误通常表示：");
        NSLog(@"[MRDLNA]    1. 正在模拟器上运行（模拟器不支持 UDP 多播）");
        NSLog(@"[MRDLNA]    2. WiFi 网络未连接 / 新系统缺 multicast entitlement");
        NSLog(@"[MRDLNA]    3. 路由器开启了 AP 隔离");
        @synchronized (self) {
            self.retryCount = 0;
        }
        [self onError:error];
        [self notifySearchDidStop];
        return;
    }
    
    // 其它错误：最多重试 2 次（保持同一 search session，不再次 didStartSearch）
    BOOL shouldRetry = NO;
    NSInteger retryCount = 0;
    @synchronized (self) {
        if (self.retryCount < 2) {
            self.retryCount++;
            retryCount = self.retryCount;
            self.closingForRetry = YES;
            shouldRetry = YES;
        } else {
            self.retryCount = 0;
        }
    }
    if (shouldRetry) {
        NSLog(@"[MRDLNA] 尝试重试 (%ld/2)...", (long)retryCount);
        [_udpSocket close];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self start];
        });
    } else {
        [self onError:error];
        [self notifySearchDidStop];
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error{
    NSLog(@"[MRDLNA] udpSocket关闭, error: %@", error);
    // 重试会 close 旧 socket 再 setupSocket；迟到的 didClose 不得结束新一轮
    if (sock != _udpSocket) {
        return;
    }
    BOOL ignoreClose = NO;
    @synchronized (self) {
        ignoreClose = self.closingForRetry;
    }
    if (ignoreClose) {
        return;
    }
    if (error) {
        [self onError:error];
    }
    // 当前 socket 异常关闭且本轮仍在搜：结束，避免上层一直「搜索中」
    [self notifySearchDidStop];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(nullable id)filterContext{
    [self JudgeDeviceWithData:data];
}

// 判断设备
- (void)JudgeDeviceWithData:(NSData *)data{
    @autoreleasepool {
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!string) {
            NSLog(@"[MRDLNA] 收到无法解码的数据");
            return;
        }
        
        NSLog(@"[MRDLNA] 收到响应: %@", [string substringToIndex:MIN(200, string.length)]);
        
        if ([string hasPrefix:@"NOTIFY"]) {
            NSString *serviceType = [self headerValueForKey:@"NT:" inData:string];
            NSLog(@"[MRDLNA] NOTIFY - NT: %@", serviceType);
            
            if ([serviceType isEqualToString:serviceType_AVTransport]) {
                NSString *location = [self headerValueForKey:@"Location:" inData:string];
                NSString *usn = [self headerValueForKey:@"USN:" inData:string];
                NSString *ssdp = [self headerValueForKey:@"NTS:" inData:string];
                if ([self isNilString:ssdp]) {
                    NSLog(@"[MRDLNA] ssdp = nil");
                    return;
                }
                if ([self isNilString:usn]) {
                    NSLog(@"[MRDLNA] usn = nil");
                    return;
                }
                if ([self isNilString:location]) {
                    NSLog(@"[MRDLNA] location = nil");
                    return;
                }
                NSLog(@"[MRDLNA] NOTIFY设备 - location: %@, usn: %@", location, usn);
                
                if ([ssdp isEqualToString:@"ssdp:alive"])
                {
                    dispatch_async(_queue, ^{
                        if ([self.deviceDictionary objectForKey:usn] == nil)
                        {
                            [self addDevice:[self getDeviceWithLocation:location withUSN:usn] forUSN:usn];
                        }
                    });
                }
                else if ([ssdp isEqualToString:@"ssdp:byebye"])
                {
                    dispatch_async(_queue, ^{
                        [self removeDeviceWithUSN:usn];
                    });
                }
            }
        }else if ([string hasPrefix:@"HTTP/1.1"]){
            NSString *location = [self headerValueForKey:@"Location:" inData:string];
            NSString *usn = [self headerValueForKey:@"USN:" inData:string];
            
            NSLog(@"[MRDLNA] HTTP响应 - location: %@, usn: %@", location, usn);
            
            if ([self isNilString:usn]) {
                NSLog(@"[MRDLNA] usn = nil");
                return;
            }
            if ([self isNilString:location]) {
                NSLog(@"[MRDLNA] location = nil");
                return;
            }
            dispatch_async(_queue, ^{
                if ([self.deviceDictionary objectForKey:usn] == nil)
                {
                    NSLog(@"[MRDLNA] 正在获取设备详情: %@", location);
                    [self addDevice:[self getDeviceWithLocation:location withUSN:usn] forUSN:usn];
                }
            });
        }
    }
}

- (void)addDevice:(CLUPnPDevice *)device forUSN:(NSString *)usn
{
    if (!device){
        NSLog(@"[MRDLNA] addDevice: device is nil for USN: %@", usn);
        return;
    }
    NSLog(@"[MRDLNA] 添加设备: %@ (%@)", device.friendlyName, usn);
    [self.deviceDictionary setObject:device forKey:usn];
    [self onChange];
}

- (void)removeDeviceWithUSN:(NSString *)usn
{
    [self.deviceDictionary removeObjectForKey:usn];
    [self onChange];
}

- (void)onChange{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.receiveDevice && self.delegate && [self.delegate respondsToSelector:@selector(upnpSearchChangeWithResults:)]){
            [self.delegate upnpSearchChangeWithResults:self.deviceDictionary.allValues];
        }
    });
}

- (void)onError:(NSError *)error{
    if (self.delegate && [self.delegate respondsToSelector:@selector(upnpSearchErrorWithError:)]) {
        [self.delegate upnpSearchErrorWithError:error];
    }
}

#pragma mark -
#pragma mark -- private method --
- (NSString *)headerValueForKey:(NSString *)key inData:(NSString *)data
{
    NSString *str = [NSString stringWithFormat:@"%@", data];
    
    NSRange keyRange = [str rangeOfString:key options:NSCaseInsensitiveSearch];
    
    if (keyRange.location == NSNotFound){
        return @"";
    }
    
    str = [str substringFromIndex:keyRange.location + keyRange.length];
    
    NSRange enterRange = [str rangeOfString:@"\r\n"];
    
    NSString *value = [[str substringToIndex:enterRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return value;
}

- (CLUPnPDevice *)getDeviceWithLocation:(NSString *)location withUSN:(NSString *)usn
{
    if ([self isNilString:location]) {
        NSLog(@"[MRDLNA] getDeviceWithLocation: location is nil");
        return nil;
    }
    
    dispatch_semaphore_t seamphore = dispatch_semaphore_create(0);
    
    __block CLUPnPDevice *device = nil;
    NSURL *URL = [NSURL URLWithString:location];
    
    if (!URL) {
        NSLog(@"[MRDLNA] getDeviceWithLocation: invalid URL: %@", location);
        return nil;
    }
    
    NSLog(@"[MRDLNA] 请求设备描述: %@", location);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0];
    request.HTTPMethod = @"GET";
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        @try {
            if (error) {
                NSLog(@"[MRDLNA] getDeviceWithLocation error: %@", error);
            } else {
                if (response != nil && data != nil) {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                    NSLog(@"[MRDLNA] 设备描述响应状态: %ld, 数据大小: %lu", (long)httpResponse.statusCode, (unsigned long)data.length);
                    
                    if (httpResponse.statusCode == 200) {
                        // 尝试不同的编码
                        NSString *xmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        if (!xmlString) {
                            // 尝试 ISO-8859-1 编码
                            xmlString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
                        }
                        if (!xmlString) {
                            NSLog(@"[MRDLNA] getDeviceWithLocation: failed to decode response");
                            dispatch_semaphore_signal(seamphore);
                            return;
                        }
                        
                        NSLog(@"[MRDLNA] 设备XML长度: %lu", (unsigned long)xmlString.length);
                        
                        NSArray *array = [CLXMLParser parseXMLArray:xmlString];
                        NSLog(@"[MRDLNA] 解析结果数组元素数: %lu", (unsigned long)array.count);
                        
                        if (array && array.count > 0) {
                            device = [[CLUPnPDevice alloc] init];
                            device.uuid = usn;
                            device.location = [NSURL URLWithString:location];
                            [device setArray:array];
                            
                            NSLog(@"[MRDLNA] 解析设备: friendlyName=%@, modelName=%@, AVTransport.controlURL=%@", 
                                  device.friendlyName, device.modelName, device.AVTransport.controlURL);
                            
                            // 验证设备信息是否有效
                            if (!device.friendlyName || device.friendlyName.length == 0) {
                                NSLog(@"[MRDLNA] getDeviceWithLocation: device friendlyName is empty");
                            }
                        } else {
                            NSLog(@"[MRDLNA] getDeviceWithLocation: failed to parse XML, array is empty");
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"[MRDLNA] getDeviceWithLocation exception: %@", exception);
        }
        dispatch_semaphore_signal(seamphore);
    }] resume];
    
    dispatch_semaphore_wait(seamphore, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC));
    return device;
}

- (BOOL)isNilString:(NSString *)string{
    if (string == nil || [string isKindOfClass:[NSNull class]] || [string isEqualToString:@""] || [string isEqualToString:@"(null)"] || [string isEqualToString:@"<null>"]) {
        return YES;
    }
    return NO;
}

@end
