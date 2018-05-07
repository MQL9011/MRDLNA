//
//  StopAction.h
//  YSTThirdSDK
//
//  Created by Eric on 2018/3/15.
//

#import <Foundation/Foundation.h>
#import "CLUPnPDevice.h"

@interface StopAction : NSObject
@property(nonatomic, strong) CLUPnPDevice *device;

- (instancetype)initWithDevice:(CLUPnPDevice *) device Success:(void(^)())successBlock failure:(void(^)())failureBlock;
-(void)executeAction;
@end
