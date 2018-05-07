//
//  StopAction.m
//  YSTThirdSDK
//
//  Created by Eric on 2018/3/15.
//

#import "StopAction.h"
#import "CLUPnPRenderer.h"

@interface StopAction ()<CLUPnPResponseDelegate>
@property (nonatomic, copy) void(^successCallback)();
@property (nonatomic, copy) void(^failureCallback)();

@property(nonatomic,strong) CLUPnPRenderer *render;         //MDR渲染器

@end
@implementation StopAction
@synthesize successCallback = _successCallback;
@synthesize failureCallback = _failureCallback;

- (instancetype)initWithDevice:(CLUPnPDevice *) device Success:(void(^)())successBlock failure:(void(^)())failureBlock
{
    self = [self init];
    
    self.successCallback = successBlock;
    self.failureCallback = failureBlock;
    
    self.render = [[CLUPnPRenderer alloc] initWithModel:device];
    self.render.delegate = self;

    return self;
}
-(void)executeAction{
    [self.render stop];
}

#pragma mark CLUPnPResponseDelegate
- (void)upnpPlayResponse{
    if (self.failureCallback) {
        self.failureCallback();
    }
}
- (void)upnpStopResponse{
    if (self.successCallback) {
        self.successCallback();
    }
}
@end
