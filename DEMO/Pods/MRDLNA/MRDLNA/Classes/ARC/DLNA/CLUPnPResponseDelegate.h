//
//  CLUPnPResponseDelegate.h
//  DLNA_UPnP
//
//  Created by ClaudeLi on 16/10/10.
//  Copyright © 2016年 ClaudeLi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CLUPnPAVPositionInfo;
@class CLUPnPTransportInfo;

// 响应解析回调协议
@protocol CLUPnPResponseDelegate <NSObject>

@required

- (void)upnpSetAVTransportURIResponse;  // 设置url响应
- (void)upnpGetTransportInfoResponse:(CLUPnPTransportInfo *)info;   // 获取播放状态

@optional

/**
 未定义的响应/错误
 
 @param resXML  响应XML
 @param postXML 请求的动作
 */
- (void)upnpUndefinedResponse:(NSString *)resXML postXML:(NSString *)postXML;

- (void)upnpPlayResponse;                   // 播放响应
- (void)upnpPauseResponse;                  // 暂停响应
- (void)upnpStopResponse;                   // 停止投屏
- (void)upnpSeekResponse;                   // 跳转响应
- (void)upnpPreviousResponse;               // 以前的响应
- (void)upnpNextResponse;                   // 下一个响应
- (void)upnpSetVolumeResponse;              // 设置音量响应
- (void)upnpSetNextAVTransportURIResponse;  // 设置下一个url响应
- (void)upnpGetVolumeResponse:(NSString *)volume;                   // 获取音频信息
- (void)upnpGetPositionInfoResponse:(CLUPnPAVPositionInfo *)info;   // 获取播放进度


@end
