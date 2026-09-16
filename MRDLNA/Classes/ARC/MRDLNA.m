//
//  MRDLNA.m
//  MRDLNA
//
//  Created by MccRee on 2018/5/4.
//

#import "MRDLNA.h"
#import "StopAction.h"

@interface MRDLNA () <CLUPnPServerDelegate, CLUPnPResponseDelegate>

@property (nonatomic, strong) CLUPnPServer *upd;
@property (nonatomic, strong) NSMutableArray *dataArray;

@property (nonatomic, strong) CLUPnPRenderer *render;
@property (nonatomic, copy) NSString *volumeValue;
@property (nonatomic, assign) NSInteger seekTime;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, copy) void (^getSeekTimeBlock)(CLUPnPAVPositionInfo *);

@end

@implementation MRDLNA

+ (MRDLNA *)sharedMRDLNAManager {
    static MRDLNA *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.upd = [CLUPnPServer shareServer];
        self.upd.searchTime = 5;
        self.upd.delegate = self;
        self.dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)startDLNA {
    [self initCLUPnPRendererAndDlnaPlay];
}

- (void)startDLNAAfterStop {
    StopAction *action = [[StopAction alloc] initWithDevice:self.device Success:^{
        [self initCLUPnPRendererAndDlnaPlay];
    } failure:^{
        [self initCLUPnPRendererAndDlnaPlay];
    }];
    [action executeAction];
}

- (void)initCLUPnPRendererAndDlnaPlay {
    self.render = [[CLUPnPRenderer alloc] initWithModel:self.device];
    self.render.delegate = self;
    [self.render setAVTransportURL:self.playUrl];
}

- (void)endDLNA {
    [self.render stop];
}

- (void)dlnaPlay {
    [self.render play];
}

- (void)dlnaPause {
    [self.render pause];
}

- (void)startSearch {
    [self.upd start];
}

- (void)volumeChanged:(NSString *)volume {
    self.volumeValue = volume;
    [self.render setVolumeWith:volume];
}

- (void)setVolume:(NSInteger)volume {
    NSInteger value = MAX(0, MIN(volume, 100));
    _volume = value;
    NSString *strValue = [NSString stringWithFormat:@"%ld", (long)value];
    [self volumeChanged:strValue];
}

- (void)seekChanged:(NSInteger)seek {
    self.seekTime = seek;
    NSString *seekStr = [self timeFormatted:seek];
    [self.render seekToTarget:seekStr Unit:unitREL_TIME];
}

- (NSString *)timeFormatted:(NSInteger)totalSeconds {
    NSInteger seconds = totalSeconds % 60;
    NSInteger minutes = (totalSeconds / 60) % 60;
    NSInteger hours = totalSeconds / 3600;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

- (void)playTheURL:(NSString *)url {
    self.playUrl = url;
    [self.render setAVTransportURL:url];
}

- (void)getSeekTime:(void (^)(CLUPnPAVPositionInfo *))block {
    self.getSeekTimeBlock = [block copy];
    [self.render getPositionInfo];
}

#pragma mark - CLUPnPServerDelegate

- (void)upnpSearchChangeWithResults:(NSArray<CLUPnPDevice *> *)devices {
    NSMutableArray *deviceMarr = [NSMutableArray array];
    for (CLUPnPDevice *device in devices) {
        if ([device.uuid containsString:serviceType_AVTransport]) {
            [deviceMarr addObject:device];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(searchDLNAResult:)]) {
            [self.delegate searchDLNAResult:[deviceMarr copy]];
        }
        self.dataArray = deviceMarr;
    });
}

- (void)upnpSearchErrorWithError:(NSError *)error {
}

- (void)didStartSearch {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlnaSearchDidStart:)]) {
            [self.delegate dlnaSearchDidStart:self];
        }
    });
}

- (void)didStopSearch {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlnaSearchDidFinish:)]) {
            [self.delegate dlnaSearchDidFinish:self];
        }
    });
}

#pragma mark - CLUPnPResponseDelegate

- (void)upnpSetAVTransportURIResponse {
    [self.render play];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:event:)]) {
            [self.delegate dlna:self event:DLNAEventNextURI];
        }
    });
}

- (void)upnpGetTransportInfoResponse:(CLUPnPTransportInfo *)info {
    if (!([info.currentTransportState isEqualToString:@"PLAYING"] ||
          [info.currentTransportState isEqualToString:@"TRANSITIONING"])) {
        [self.render play];
    }
}

- (void)upnpPreviousResponse {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:event:)]) {
            [self.delegate dlna:self event:DLNAEventPrevious];
        }
    });
}

- (void)upnpNextResponse {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:event:)]) {
            [self.delegate dlna:self event:DLNAEventNext];
        }
    });
}

- (void)upnpSeekResponse {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:event:)]) {
            [self.delegate dlna:self event:DLNAEventSeek];
        }
    });
}

- (void)upnpSetVolumeResponse {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:event:)]) {
            [self.delegate dlna:self event:DLNAEventVolume];
        }
    });
}

- (void)upnpGetVolumeResponse:(NSString *)volume {
    self.volumeValue = volume;
    _volume = volume.integerValue;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:event:)]) {
            [self.delegate dlna:self event:DLNAEventVolume];
        }
    });
}

- (void)upnpPlayResponse {
    self.state = DLNAStatePlay;
    [self.render getVolume];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlnaStartPlay)]) {
            [self.delegate dlnaStartPlay];
        }
        if ([self.delegate respondsToSelector:@selector(dlna:state:)]) {
            [self.delegate dlna:self state:DLNAStatePlay];
        }
    });
}

- (void)upnpStopResponse {
    self.state = DLNAStateStop;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:state:)]) {
            [self.delegate dlna:self state:DLNAStateStop];
        }
    });
}

- (void)upnpPauseResponse {
    self.state = DLNAStatePause;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(dlna:state:)]) {
            [self.delegate dlna:self state:DLNAStatePause];
        }
    });
}

- (void)upnpGetPositionInfoResponse:(CLUPnPAVPositionInfo *)info {
    void (^block)(CLUPnPAVPositionInfo *) = self.getSeekTimeBlock;
    self.getSeekTimeBlock = nil;
    if (!block) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        block(info);
    });
}

#pragma mark - Set & Get

- (void)setSearchTime:(NSInteger)searchTime {
    _searchTime = searchTime;
    self.upd.searchTime = searchTime;
}

@end
