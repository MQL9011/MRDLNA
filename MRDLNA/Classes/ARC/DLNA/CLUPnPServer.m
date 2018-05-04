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
#import "GDataXMLNode.h"

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
    return [NSString stringWithFormat:@"M-SEARCH * HTTP/1.1\r\nHOST: %@:%d\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: %@\r\nUSER-AGENT: iOS UPnP/1.1 mccree/1.0\r\n\r\n", ssdpAddres, ssdpPort, serviceType_AVTransport];
}

- (void)start{
    NSError *error = nil;
    if (![_udpSocket bindToPort:ssdpPort error:&error]){
        [self onError:error];
    }
    
    if (![_udpSocket beginReceiving:&error])
    {
        [self onError:error];
    }
    
    if (![_udpSocket joinMulticastGroup:ssdpAddres error:&error])
    {
        [self onError:error];
    }
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
    CLLog(@"udpSocket关闭");
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
//    NSLog(@"%@",device.description);
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
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];
    request.HTTPMethod = @"GET";
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [self onError:error];
        }else{
            if (response != nil && data != nil) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if ([httpResponse statusCode] == 200) {
                    device = [[CLUPnPDevice alloc] init];
                    device.loaction = URL;
                    device.uuid = usn;
                    GDataXMLDocument *xmlDoc = [[GDataXMLDocument alloc] initWithData:data options:0 error:nil];
                    GDataXMLElement *xmlEle = [xmlDoc rootElement];
                    NSArray *xmlArray = [xmlEle children];
                    
                    for (int i = 0; i < [xmlArray count]; i++) {
                        GDataXMLElement *element = [xmlArray objectAtIndex:i];
                        if ([[element name] isEqualToString:@"device"]) {
                            [device setArray:[element children]];
                            continue;
                        }
                    }
                }
            }
        }
        dispatch_semaphore_signal(seamphore);
    }] resume];
    dispatch_semaphore_wait(seamphore, DISPATCH_TIME_FOREVER);
    return device;
}

- (BOOL)isNilString:(NSString *)_str{
    if(_str == nil || _str == NULL || [_str isEqual:@"null"] || [_str isEqual:[NSNull null]] || [_str isKindOfClass:[NSNull class]]){
        return YES;
    }
    if (![_str isKindOfClass:[NSString class]]) {
        return YES;
    }
    _str = [NSString stringWithFormat:@"%@", _str];
    if([_str isEqualToString:@"(null)"]){
        return YES;
    }
    if ([_str isEqualToString:@""]) {
        return YES;
    }
    if ([_str isEqualToString:@"<null>"]) {
        return YES;
    }
    return NO;
}

@end
