#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CLXMLParser : NSObject

+ (NSDictionary *)parseXMLString:(NSString *)xmlString;
+ (NSArray *)parseXMLArray:(NSString *)xmlString;

@end

NS_ASSUME_NONNULL_END 