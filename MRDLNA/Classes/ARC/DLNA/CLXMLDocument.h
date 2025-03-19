#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CLXMLDocument : NSObject

@property (nonatomic, strong, readonly) NSString *XMLString;

+ (instancetype)elementWithName:(NSString *)name;
+ (instancetype)attributeWithName:(NSString *)name stringValue:(NSString *)value;
- (void)addChild:(CLXMLDocument *)child;
- (void)addAttribute:(CLXMLDocument *)attribute;
- (void)setStringValue:(NSString *)value;

@end

NS_ASSUME_NONNULL_END 