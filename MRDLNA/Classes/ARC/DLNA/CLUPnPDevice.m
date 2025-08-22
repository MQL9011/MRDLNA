//
//  CLUPnPDevice.m
//  DLNA_UPnP
//
//  Created by ClaudeLi on 2017/7/31.
//  Copyright © 2017年 ClaudeLi. All rights reserved.
//

#import "CLUPnP.h"
#import "CLXMLParser.h"

@implementation CLUPnPDevice

- (CLServiceModel *)AVTransport{
    if (!_AVTransport) {
        _AVTransport = [[CLServiceModel alloc] init];
    }
    return _AVTransport;
}

- (CLServiceModel *)RenderingControl{
    if (!_RenderingControl) {
        _RenderingControl = [[CLServiceModel alloc] init];
    }
    return _RenderingControl;
}

- (NSString *)URLHeader{
    if (!_URLHeader) {
        _URLHeader = [NSString stringWithFormat:@"%@://%@:%@", [self.location scheme], [self.location host], [self.location port]];
    }
    return _URLHeader;
}

- (void)setArray:(NSArray *)array{
    @autoreleasepool {
        for (NSDictionary *dict in array) {
            if ([dict[@"friendlyName"] isKindOfClass:[NSString class]]) {
                self.friendlyName = dict[@"friendlyName"];
            }
            if ([dict[@"modelName"] isKindOfClass:[NSString class]]) {
                self.modelName = dict[@"modelName"];
            }
            if ([dict[@"serviceList"] isKindOfClass:[NSArray class]]) {
                NSArray *serviceListArray = dict[@"serviceList"];
                for (NSDictionary *serviceDict in serviceListArray) {
                    if ([serviceDict[@"service"] isKindOfClass:[NSString class]]) {
                        NSString *serviceString = serviceDict[@"service"];
                        if ([serviceString rangeOfString:serviceType_AVTransport].location != NSNotFound || 
                            [serviceString rangeOfString:serviceId_AVTransport].location != NSNotFound) {
                            [self.AVTransport setArray:serviceDict[@"children"]];
                        } else if ([serviceString rangeOfString:serviceType_RenderingControl].location != NSNotFound || 
                                  [serviceString rangeOfString:serviceId_RenderingControl].location != NSNotFound) {
                            [self.RenderingControl setArray:serviceDict[@"children"]];
                        }
                    }
                }
                continue;
            }
        }
    }
}

- (NSString *)description{
    NSString * string = [NSString stringWithFormat:@"\nuuid:%@\nlocation:%@\nURLHeader:%@\nfriendlyName:%@\nmodelName:%@\n",self.uuid,self.location,self.URLHeader,self.friendlyName,self.modelName];
    return string;
}

@end

@implementation CLServiceModel

- (void)setArray:(NSArray *)array{
    @autoreleasepool {
        for (NSDictionary *dict in array) {
            if ([dict[@"serviceType"] isKindOfClass:[NSString class]]) {
                self.serviceType = dict[@"serviceType"];
            }
            if ([dict[@"serviceId"] isKindOfClass:[NSString class]]) {
                self.serviceId = dict[@"serviceId"];
            }
            if ([dict[@"controlURL"] isKindOfClass:[NSString class]]) {
                self.controlURL = dict[@"controlURL"];
            }
            if ([dict[@"eventSubURL"] isKindOfClass:[NSString class]]) {
                self.eventSubURL = dict[@"eventSubURL"];
            }
            if ([dict[@"SCPDURL"] isKindOfClass:[NSString class]]) {
                self.SCPDURL = dict[@"SCPDURL"];
            }
        }
    }
}

@end
