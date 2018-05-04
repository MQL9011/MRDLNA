//
//  CLUPnPDevice.h
//  DLNA_UPnP
//
//  Created by ClaudeLi on 2017/7/31.
//  Copyright © 2017年 ClaudeLi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CLServiceModel;

@interface CLUPnPDevice : NSObject

@property (nonatomic, copy) NSString    *uuid;
@property (nonatomic, strong) NSURL     *loaction;
@property (nonatomic, copy) NSString    *URLHeader;

@property (nonatomic, copy) NSString *friendlyName;
@property (nonatomic, copy) NSString *modelName;

@property (nonatomic, strong) CLServiceModel *AVTransport;
@property (nonatomic, strong) CLServiceModel *RenderingControl;

- (void)setArray:(NSArray *)array;

@end

@interface CLServiceModel : NSObject

@property (nonatomic, copy) NSString *serviceType;
@property (nonatomic, copy) NSString *serviceId;
@property (nonatomic, copy) NSString *controlURL;
@property (nonatomic, copy) NSString *eventSubURL;
@property (nonatomic, copy) NSString *SCPDURL;

- (void)setArray:(NSArray *)array;

@end
