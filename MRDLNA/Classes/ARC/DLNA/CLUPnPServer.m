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
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    }
    return self;
}

- (NSString *)getSearchString{
    return [NSString stringWithFormat:@"M-SEARCH * HTTP/1.1\r\nHOST: %@:%d\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: %@\r\nUSER-AGENT: iOS UPnP/1.1 MRDLNA/0.3.0\r\n\r\n", ssdpAddres, ssdpPort, serviceType_AVTransport];
}

- (void)searchForAllDevices {
    // 搜索所有UPnP设备，提高发现率
    NSArray *searchTypes = @[
        @"upnp:rootdevice",
        @"urn:schemas-upnp-org:device:MediaRenderer:1",
        @"urn:schemas-upnp-org:service:AVTransport:1",
        @"ssdp:all"
    ];
    
    for (NSString *searchType in searchTypes) {
        NSString *searchString = [NSString stringWithFormat:@"M-SEARCH * HTTP/1.1\r\nHOST: %@:%d\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: %@\r\nUSER-AGENT: iOS UPnP/1.1 MRDLNA/0.3.0\r\n\r\n", ssdpAddres, ssdpPort, searchType];
        NSData *sendData = [searchString dataUsingEncoding:NSUTF8StringEncoding];
        [_udpSocket sendData:sendData toHost:ssdpAddres port:ssdpPort withTimeout:-1 tag:1];
        
        // 小延迟避免网络拥堵
        usleep(100000); // 100ms
    }
}

- (void)start{
    NSError *error = nil;
    
    // 先停止之前的socket避免冲突
    [_udpSocket close];
    
    // 重新初始化socket
    _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    // iOS 16+ 需要先尝试绑定到0端口，让系统自动分配
    if (![_udpSocket bindToPort:0 error:&error]) {
        CLLog(@"绑定端口失败: %@", error);
        [self onError:error];
        return;
    }
    
    if (![_udpSocket beginReceiving:&error]) {
        CLLog(@"开始接收数据失败: %@", error);
        [self onError:error];
        return;
    }
    
    if (![_udpSocket joinMulticastGroup:ssdpAddres error:&error]) {
        CLLog(@"加入组播组失败: %@", error);
        [self onError:error];
        return;
    }
    
    CLLog(@"UDP Socket 启动成功");
    [self search];
}

- (void)stop{
    [_udpSocket close];
}

- (void)search{
    // 搜索前先清空设备列表
    [self.deviceDictionary removeAllObjects];
    self.receiveDevice = YES;
    [self onChange];
    
    // 使用增强的搜索方法
    [self searchForAllDevices];
    
    // 备用的标准搜索
    NSData * sendData = [[self getSearchString] dataUsingEncoding:NSUTF8StringEncoding];
    [_udpSocket sendData:sendData toHost:ssdpAddres port:ssdpPort withTimeout:-1 tag:1];
}

- (NSArray<CLUPnPDevice *> *)getDeviceList{
    return self.deviceDictionary.allValues;
}


#pragma mark -- GCDAsyncUdpSocketDelegate --
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag{
    CLLog(@"发送信息成功");
     __weak typeof (self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(weakSelf.searchTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakSelf.receiveDevice = NO;
        CLLog(@"搜索结束");
    });
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error{
    [self onError:error];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error{
    CLLog(@"udpSocket关闭 - Error: %@", error);
    
    // iOS 16+ 网络权限问题处理
    if (error) {
        [self onError:error];
        
        // 自动重连机制 (避免频繁重连)
        static NSTimeInterval lastReconnectTime = 0;
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        
        if (currentTime - lastReconnectTime > 5.0) { // 5秒内不重复重连
            lastReconnectTime = currentTime;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CLLog(@"尝试重新启动UDP socket");
                [self start];
            });
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(nullable id)filterContext{
    [self JudgeDeviceWithData:data];
}

// 判断设备
- (void)JudgeDeviceWithData:(NSData *)data{
    @autoreleasepool {
        if (!data || data.length == 0) {
            CLLog(@"收到空数据，跳过处理");
            return;
        }
        
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!string || string.length == 0) {
            CLLog(@"数据解码失败，尝试其他编码");
            string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            if (!string) {
                return;
            }
        }
        
        if ([string hasPrefix:@"NOTIFY"]) {
            NSString *serviceType = [self headerValueForKey:@"NT:" inData:string];
            if ([serviceType isEqualToString:serviceType_AVTransport]) {
                NSString *location = [self headerValueForKey:@"Location:" inData:string];
                NSString *usn = [self headerValueForKey:@"USN:" inData:string];
                NSString *ssdp = [self headerValueForKey:@"NTS:" inData:string];
                if ([self isNilString:ssdp]) {
                    CLLog(@"ssdp = nil");
                    return;
                }
                if ([self isNilString:usn]) {
                    CLLog(@"usn = nil");
                    return;
                }
                if ([self isNilString:location]) {
                    CLLog(@"location = nil");
                    return;
                }
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
            if ([self isNilString:usn]) {
                CLLog(@"usn = nil");
                return;
            }
            if ([self isNilString:location]) {
                CLLog(@"location = nil");
                return;
            }
            dispatch_async(_queue, ^{
                if ([self.deviceDictionary objectForKey:usn] == nil)
                {
                    [self addDevice:[self getDeviceWithLocation:location withUSN:usn] forUSN:usn];
                }
            });
        }
    }
}

- (void)addDevice:(CLUPnPDevice *)device forUSN:(NSString *)usn
{
    if (!device){
        return;
    }
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
    dispatch_semaphore_t seamphore = dispatch_semaphore_create(0);
    
    __block CLUPnPDevice *device = nil;
    NSURL *URL = [NSURL URLWithString:location];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0];
    request.HTTPMethod = @"GET";
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [self onError:error];
        }else{
            if (response != nil && data != nil) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == 200) {
                    NSString *xmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSArray *array = [CLXMLParser parseXMLArray:xmlString];
                    device = [[CLUPnPDevice alloc] init];
                    device.uuid = usn;
                    device.location = location;
                    [device setArray:array];
                }
            }
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

- (void)checkNetworkPermission {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 简单的网络连通性测试
        NSURL *testURL = [NSURL URLWithString:@"http://www.apple.com"];
        NSURLRequest *request = [NSURLRequest requestWithURL:testURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            BOOL hasPermission = (error == nil);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                CLLog(@"网络权限检查结果: %@", hasPermission ? @"正常" : @"异常");
                if (self.delegate && [self.delegate respondsToSelector:@selector(upnpNetworkPermissionStatus:)]) {
                    [self.delegate upnpNetworkPermissionStatus:hasPermission];
                }
                
                if (!hasPermission) {
                    NSError *networkError = [NSError errorWithDomain:@"MRDLNANetworkDomain" 
                                                               code:-1001 
                                                           userInfo:@{NSLocalizedDescriptionKey: @"网络权限受限，请检查设置"}];
                    [self onError:networkError];
                }
            });
        }];
        
        [task resume];
    });
}

@end
