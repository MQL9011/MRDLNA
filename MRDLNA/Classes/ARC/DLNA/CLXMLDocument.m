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

/**
 对齐旧版 GDataXML → libxml2 `xmlEncodeSpecialChars` / `xmlNodeDump` 的特殊字符转义
 （不链 xml2，规则对齐 libxml2：& < > " 以及 CR）:
   & → &amp;   < → &lt;   > → &gt;   " → &quot;   CR → &#13;
 存节点时仍保持明文；仅在 XMLString 序列化时转义（与 GData 一致）。
 */
+ (NSString *)xmlEscaped:(NSString *)string {
    if (string.length == 0) {
        return string ?: @"";
    }
    // 按字符扫描，避免多次 replace 在大 DIDL 上的开销；& 必须先于其它实体语义处理。
    NSUInteger length = string.length;
    NSMutableString *escaped = [NSMutableString stringWithCapacity:length + 16];
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [string characterAtIndex:i];
        switch (c) {
            case '&':
                [escaped appendString:@"&amp;"];
                break;
            case '<':
                [escaped appendString:@"&lt;"];
                break;
            case '>':
                [escaped appendString:@"&gt;"];
                break;
            case '"':
                [escaped appendString:@"&quot;"];
                break;
            case '\r':
                [escaped appendString:@"&#13;"];
                break;
            default:
                [escaped appendFormat:@"%C", c];
                break;
        }
    }
    return escaped;
}

- (NSString *)XMLString {
    NSMutableString *xmlString = [NSMutableString string];
    
    NSMutableString *attributeString = [NSMutableString string];
    for (CLXMLDocument *attribute in self.attributes) {
        [attributeString appendFormat:@" %@=\"%@\"", attribute.name, [CLXMLDocument xmlEscaped:attribute.value]];
    }
    
    [xmlString appendFormat:@"<%@%@>", self.name, attributeString];
    
    for (CLXMLDocument *child in self.children) {
        [xmlString appendString:child.XMLString];
    }
    
    if (self.value) {
        [xmlString appendString:[CLXMLDocument xmlEscaped:self.value]];
    }
    
    [xmlString appendFormat:@"</%@>", self.name];
    
    return xmlString;
}

@end
