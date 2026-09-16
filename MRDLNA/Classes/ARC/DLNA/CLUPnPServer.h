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

/// 开始一轮搜索。与 didStopSearch 成对：调用 start/search 后，超时、发送失败、绑定失败或主动 stop 等终态都会回调一次。
- (void)didStartSearch;
/// 本轮搜索结束。同一轮最多一次；失败与成功超时都走这里，保证上层能退出「搜索中」。
- (void)didStopSearch;

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

@end
