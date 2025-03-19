#import "CLXMLDocument.h"

@interface CLXMLDocument ()

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSMutableArray<CLXMLDocument *> *children;
@property (nonatomic, strong) NSMutableArray<CLXMLDocument *> *attributes;
@property (nonatomic, strong) NSString *value;

@end

@implementation CLXMLDocument

- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [NSMutableArray array];
        _attributes = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)elementWithName:(NSString *)name {
    CLXMLDocument *element = [[CLXMLDocument alloc] init];
    element.name = name;
    return element;
}

+ (instancetype)attributeWithName:(NSString *)name stringValue:(NSString *)value {
    CLXMLDocument *attribute = [[CLXMLDocument alloc] init];
    attribute.name = name;
    attribute.value = value;
    return attribute;
}

- (void)addChild:(CLXMLDocument *)child {
    [self.children addObject:child];
}

- (void)addAttribute:(CLXMLDocument *)attribute {
    [self.attributes addObject:attribute];
}

- (void)setStringValue:(NSString *)value {
    self.value = value;
}

- (NSString *)XMLString {
    NSMutableString *xmlString = [NSMutableString string];
    
    // Add attributes
    NSMutableString *attributeString = [NSMutableString string];
    for (CLXMLDocument *attribute in self.attributes) {
        [attributeString appendFormat:@" %@=\"%@\"", attribute.name, attribute.value];
    }
    
    // Start element
    [xmlString appendFormat:@"<%@%@>", self.name, attributeString];
    
    // Add children
    for (CLXMLDocument *child in self.children) {
        [xmlString appendString:child.XMLString];
    }
    
    // Add value if exists
    if (self.value) {
        [xmlString appendString:self.value];
    }
    
    // End element
    [xmlString appendFormat:@"</%@>", self.name];
    
    return xmlString;
}

@end 