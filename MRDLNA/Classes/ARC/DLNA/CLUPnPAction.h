//
//  CLUPnPAction.h
//  DLNA_UPnP
//
//  Created by ClaudeLi on 16/10/10.
//  Copyright © 2016年 ClaudeLi. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CLUPnPServiceType) {
    CLUPnPServiceAVTransport,       // @"urn:schemas-upnp-org:service:AVTransport:1"
    CLUPnPServiceRenderingControl,  // @"urn:schemas-upnp-org:service:RenderingControl:1"
};

@class CLUPnPDevice;
@interface CLUPnPAction : NSObject

// serviceType 默认 CLUPnPServiceAVTransport
@property (nonatomic, assign) CLUPnPServiceType serviceType;

- (instancetype)initWithAction:(NSString *)action;

- (void)setArgumentValue:(NSString *)value forName:(NSString *)name;

- (NSString *)getServiceType;

- (NSString *)getSOAPAction;

- (NSString *)getPostUrlStrWith:(CLUPnPDevice *)model;

- (NSString *)getPostXMLFile;

@end
