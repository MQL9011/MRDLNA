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
@property (nonatomic, assign) float absTime;
@property (nonatomic, assign) float relTime;

- (void)setArray:(NSArray *)array;

@end


@interface CLUPnPTransportInfo : NSObject

@property (nonatomic, copy) NSString *currentTransportState;
@property (nonatomic, copy) NSString *currentTransportStatus;
@property (nonatomic, copy) NSString *currentSpeed;

- (void)setArray:(NSArray *)array;

@end


@interface NSString(UPnP)

+(NSString *)stringWithDurationTime:(float)timeValue;
- (float)durationTime;

@end
