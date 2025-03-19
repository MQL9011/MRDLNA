//
//  CLUPnPAVPositionInfo.h
//  DLNA_UPnP
//
//  Created by ClaudeLi on 16/10/10.
//  Copyright © 2016年 ClaudeLi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CLUPnPAVPositionInfo : NSObject

@property (nonatomic, assign) float trackDuration;
@property (nonatomic, assign) float relTime;
@property (nonatomic, assign) float absTime;

- (void)setDictionary:(NSDictionary *)dict;

@end


@interface CLUPnPTransportInfo : NSObject

@property (nonatomic, strong) NSString *currentTransportState;
@property (nonatomic, strong) NSString *currentTransportStatus;
@property (nonatomic, strong) NSString *currentSpeed;

- (void)setDictionary:(NSDictionary *)dict;

@end


@interface NSString(UPnP)

+(NSString *)stringWithDurationTime:(float)timeValue;
- (float)durationTime;

@end
