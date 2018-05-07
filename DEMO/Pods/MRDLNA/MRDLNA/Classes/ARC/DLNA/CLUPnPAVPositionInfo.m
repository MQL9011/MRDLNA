//
//  CLUPnPAVPositionInfo.m
//  DLNA_UPnP
//
//  Created by ClaudeLi on 16/10/10.
//  Copyright © 2016年 ClaudeLi. All rights reserved.
//

#import "CLUPnPAVPositionInfo.h"
#import "GDataXMLNode.h"

@implementation CLUPnPAVPositionInfo

- (void)setArray:(NSArray *)array{
    @autoreleasepool {
        for (int m = 0; m < array.count; m++) {
            GDataXMLElement *needEle = [array objectAtIndex:m];
            if ([needEle.name isEqualToString:@"TrackDuration"]) {
                self.trackDuration = [[needEle stringValue] durationTime];
            }
            if ([needEle.name isEqualToString:@"RelTime"]) {
                self.relTime = [[needEle stringValue] durationTime];
            }
            if ([needEle.name isEqualToString:@"AbsTime"]) {
                self.absTime = [[needEle stringValue] durationTime];
            }
        }
    }
}

@end

@implementation CLUPnPTransportInfo

- (void)setArray:(NSArray *)array{
    @autoreleasepool {        
        for (int m = 0; m < array.count; m++) {
            GDataXMLElement *needEle = [array objectAtIndex:m];
            if ([needEle.name isEqualToString:@"CurrentTransportState"]) {
                self.currentTransportState = [needEle stringValue];
            }
            if ([needEle.name isEqualToString:@"CurrentTransportStatus"]) {
                self.currentTransportStatus = [needEle stringValue];
            }
            if ([needEle.name isEqualToString:@"CurrentSpeed"]) {
                self.currentSpeed = [needEle stringValue];
            }
        }
    }
}

@end


@implementation  NSString(UPnP)
/*
 H+:MM:SS[.F+] or H+:MM:SS[.F0/F1]
 where :
 •	H+ means one or more digits to indicate elapsed hours
 •	MM means exactly 2 digits to indicate minutes (00 to 59)
 •	SS means exactly 2 digits to indicate seconds (00 to 59)
 •	[.F+] means optionally a dot followed by one or more digits to indicate fractions of seconds
 •	[.F0/F1] means optionally a dot followed by a fraction, with F0 and F1 at least one digit long, and F0 < F1
 */
+(NSString *)stringWithDurationTime:(float)timeValue
{
    return [NSString stringWithFormat:@"%02d:%02d:%02d",
            (int)(timeValue / 3600.0),
            (int)(fmod(timeValue, 3600.0) / 60.0),
            (int)fmod(timeValue, 60.0)];
}

- (float)durationTime
{
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
