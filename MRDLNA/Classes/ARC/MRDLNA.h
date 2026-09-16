//
//  MRDLNA.h
//  MRDLNA
//
//  Created by MccRee on 2018/5/4.
//

#import <Foundation/Foundation.h>
#import "CLUPnP.h"
#import "CLUPnPDevice.h"

typedef NS_ENUM(NSUInteger, DLNAState) {
    DLNAStatePlay,
    DLNAStatePause,
    DLNAStateStop,
};

typedef NS_ENUM(NSUInteger, DLNAEvent) {
    DLNAEventSeek,
    DLNAEventPrevious,
    DLNAEventNext,
    DLNAEventNextURI,
    DLNAEventVolume,
};

@class MRDLNA;

@protocol DLNADelegate <NSObject>

@optional
/**
 DLNA局域网搜索设备结果
 @param devicesArray <CLUPnPDevice *> 搜索到的设备
 */
- (void)searchDLNAResult:(NSArray *)devicesArray;

/// 与 dlnaSearchDidFinish: 成对；startSearch 后终态必有且仅有一次 Finish（含失败）。
- (void)dlnaSearchDidStart:(MRDLNA *)dlna;
- (void)dlnaSearchDidFinish:(MRDLNA *)dlna;
- (void)dlna:(MRDLNA *)dlna event:(DLNAEvent)event;
- (void)dlna:(MRDLNA *)dlna state:(DLNAState)state;

/**
 投屏成功开始播放
 */
- (void)dlnaStartPlay;

@end

@interface MRDLNA : NSObject

@property (nonatomic, weak) id<DLNADelegate> delegate;

@property (nonatomic, strong) CLUPnPDevice *device;

@property (nonatomic, copy) NSString *playUrl;

@property (nonatomic, assign) NSInteger searchTime;

@property (nonatomic, assign) DLNAState state;

/// 音量 0–100（读写都会走渲染器）
@property (nonatomic, assign) NSInteger volume;

/**
 单例
 */
+ (instancetype)sharedMRDLNAManager;

/**
 搜设备
 */
- (void)startSearch;

/**
 DLNA投屏
 */
- (void)startDLNA;

/**
 DLNA投屏(首先停止)---投屏不了可以使用这个方法
 ** 【流程: 停止 ->设置代理 ->设置Url -> 播放】
 */
- (void)startDLNAAfterStop;

/**
 退出DLNA
 */
- (void)endDLNA;

/**
 播放
 */
- (void)dlnaPlay;

/**
 暂停
 */
- (void)dlnaPause;

/**
 设置音量 volume建议传0-100之间字符串
 */
- (void)volumeChanged:(NSString *)volume;

/**
 设置播放进度 seek单位是秒
 */
- (void)seekChanged:(NSInteger)seek;

/**
 播放切集
 */
- (void)playTheURL:(NSString *)url;

/**
 获取播放进度。切记在回调执行后再发起下一次 getSeekTime。
 */
- (void)getSeekTime:(void (^)(CLUPnPAVPositionInfo *info))block;

@end
