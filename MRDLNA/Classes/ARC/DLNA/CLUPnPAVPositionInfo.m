//
//  CLUPnPAVPositionInfo.m
//  DLNA_UPnP
//
//  Created by ClaudeLi on 16/10/10.
//  Copyright © 2016年 ClaudeLi. All rights reserved.
//

#import "CLUPnPAVPositionInfo.h"
#import "CLXMLParser.h"

@implementation CLUPnPAVPositionInfo

- (void)setArray:(NSArray *)array {
    @autoreleasepool {
        for (NSDictionary *dict in array) {
            if ([dict[@"TrackDuration"] isKindOfClass:[NSString class]]) {
                self.trackDuration = [dict[@"TrackDuration"] durationTime];
            }
            if ([dict[@"RelTime"] isKindOfClass:[NSString class]]) {
                self.relTime = [dict[@"RelTime"] durationTime];
            }
            if ([dict[@"AbsTime"] isKindOfClass:[NSString class]]) {
                self.absTime = [dict[@"AbsTime"] durationTime];
            }
        }
    }
}

@end

@implementation CLUPnPTransportInfo

- (void)setArray:(NSArray *)array {
    @autoreleasepool {        
        for (NSDictionary *dict in array) {
            if ([dict[@"CurrentTransportState"] isKindOfClass:[NSString class]]) {
                self.currentTransportState = dict[@"CurrentTransportState"];
            }
            if ([dict[@"CurrentTransportStatus"] isKindOfClass:[NSString class]]) {
                self.currentTransportStatus = dict[@"CurrentTransportStatus"];
            }
            if ([dict[@"CurrentSpeed"] isKindOfClass:[NSString class]]) {
                self.currentSpeed = dict[@"CurrentSpeed"];
            }
        }
    }
}

@end

@implementation NSString(UPnP)

+(NSString *)stringWithDurationTime:(float)timeValue {
    return [NSString stringWithFormat:@"%02d:%02d:%02d",
            (int)(timeValue / 3600.0),
            (int)(fmod(timeValue, 3600.0) / 60.0),
            (int)fmod(timeValue, 60.0)];
}

- (float)durationTime {
    NSArray *timeStrings = [self componentsSeparatedByString:@":"];
    int timeStringsCount = (int)[timeStrings count];
    if (timeStringsCount < 3)
        return -1.0f;
    float durationTime = 0.0;
    for (int n = 0; n<timeStringsCount; n++) {
        NSString *timeString = [timeStrings objectAtIndex:n];
        int timeIntValue = [timeString intValue];
        switch (n) {
            case 0: // HH
                durationTime += timeIntValue * (60 * 60);
                break;
            case 1: // MM
                durationTime += timeIntValue * 60;
                break;
            case 2: // SS
                durationTime += timeIntValue;
                break;
            case 3: // .F?
                durationTime += timeIntValue * 0.1;
                break;
            default:
                break;
        }
    }
    return durationTime;
}

@end
