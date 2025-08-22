//
//  CLUPnPServer.h
//  DLNA_UPnP
//
//  Created by ClaudeLi on 2017/7/31.
//  Copyright © 2017年 ClaudeLi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CLUPnPDevice;
@protocol CLUPnPServerDelegate <NSObject>
@required
/**
 搜索结果

 @param devices 设备数组
 */
- (void)upnpSearchChangeWithResults:(NSArray <CLUPnPDevice *>*)devices;

@optional
/**
 搜索失败

 @param error error
 */
- (void)upnpSearchErrorWithError:(NSError *)error;

@optional
/**
 网络权限状态检查结果
 
 @param hasPermission 是否有网络权限
 */
- (void)upnpNetworkPermissionStatus:(BOOL)hasPermission;

@end

@interface CLUPnPServer : NSObject

@property (nonatomic, weak) id<CLUPnPServerDelegate>delegate;

@property (nonatomic,assign) NSInteger searchTime;

+ (instancetype)shareServer;

/**
 启动Server并搜索
 */
- (void)start;

/**
 停止
 */
- (void)stop;

/**
 搜索
 */
- (void)search;

/**
 获取已经发现的设备
 
 @return Device Array
 */
- (NSArray<CLUPnPDevice *> *)getDeviceList;

/**
 检查网络权限状态
 */
- (void)checkNetworkPermission;

@end
