//
//  CLUPnPDevice.m
//  DLNA_UPnP
//
//  Created by ClaudeLi on 2017/7/31.
//  Copyright © 2017年 ClaudeLi. All rights reserved.
//

#import "CLUPnP.h"
#import "GDataXMLNode.h"

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
        _URLHeader = [NSString stringWithFormat:@"%@://%@:%@", [self.loaction scheme], [self.loaction host], [self.loaction port]];
    }
    return _URLHeader;
}

- (void)setArray:(NSArray *)array{
    @autoreleasepool {
        for (int j = 0; j < [array count]; j++) {
            GDataXMLElement *ele = [array objectAtIndex:j];
            if ([ele.name isEqualToString:@"friendlyName"]) {
                self.friendlyName = [ele stringValue];
            }
            if ([ele.name isEqualToString:@"modelName"]) {
                self.modelName = [ele stringValue];
            }
            if ([ele.name isEqualToString:@"serviceList"]) {
                NSArray *serviceListArray = [ele children];
                for (int k = 0; k < [serviceListArray count]; k++) {
                    GDataXMLElement *listEle = [serviceListArray objectAtIndex:k];
                    if ([listEle.name isEqualToString:@"service"]) {
                        NSString *serviceString = [listEle stringValue];
                        if ([serviceString rangeOfString:serviceType_AVTransport].location != NSNotFound || [serviceString rangeOfString:serviceId_AVTransport].location != NSNotFound) {
                            
                            [self.AVTransport setArray:[listEle children]];
                            
                        }else if ([serviceString rangeOfString:serviceType_RenderingControl].location != NSNotFound || [serviceString rangeOfString:serviceId_RenderingControl].location != NSNotFound){
                            
                            [self.RenderingControl setArray:[listEle children]];
                        }
                    }
                }
                continue;
            }
        }
    }
}

- (NSString *)description{
    NSString * string = [NSString stringWithFormat:@"\nuuid:%@\nlocation:%@\nURLHeader:%@\nfriendlyName:%@\nmodelName:%@\n",self.uuid,self.loaction,self.URLHeader,self.friendlyName,self.modelName];
    return string;
}

@end

@implementation CLServiceModel

- (void)setArray:(NSArray *)array{
    @autoreleasepool {
        for (int m = 0; m < array.count; m++) {
            GDataXMLElement *needEle = [array objectAtIndex:m];
            if ([needEle.name isEqualToString:@"serviceType"]) {
                self.serviceType = [needEle stringValue];
            }
            if ([needEle.name isEqualToString:@"serviceId"]) {
                self.serviceId = [needEle stringValue];
            }
            if ([needEle.name isEqualToString:@"controlURL"]) {
                self.controlURL = [needEle stringValue];
            }
            if ([needEle.name isEqualToString:@"eventSubURL"]) {
                self.eventSubURL = [needEle stringValue];
            }
            if ([needEle.name isEqualToString:@"SCPDURL"]) {
                self.SCPDURL = [needEle stringValue];
            }
        }
    }
}

@end
