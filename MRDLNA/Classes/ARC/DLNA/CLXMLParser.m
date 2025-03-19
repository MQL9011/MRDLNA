#import "CLXMLParser.h"

@interface CLXMLParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSMutableDictionary *currentDictionary;
@property (nonatomic, strong) NSMutableArray *currentArray;
@property (nonatomic, strong) NSMutableString *currentString;
@property (nonatomic, strong) NSString *currentElement;

@end

@implementation CLXMLParser

+ (NSDictionary *)parseXMLString:(NSString *)xmlString {
    CLXMLParser *parser = [[CLXMLParser alloc] init];
    parser.currentDictionary = [NSMutableDictionary dictionary];
    parser.currentString = [NSMutableString string];
    
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[xmlString dataUsingEncoding:NSUTF8StringEncoding]];
    xmlParser.delegate = parser;
    [xmlParser parse];
    
    return parser.currentDictionary;
}

+ (NSArray *)parseXMLArray:(NSString *)xmlString {
    CLXMLParser *parser = [[CLXMLParser alloc] init];
    parser.currentArray = [NSMutableArray array];
    parser.currentDictionary = [NSMutableDictionary dictionary];
    parser.currentString = [NSMutableString string];
    
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[xmlString dataUsingEncoding:NSUTF8StringEncoding]];
    xmlParser.delegate = parser;
    [xmlParser parse];
    
    return parser.currentArray;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    self.currentElement = elementName;
    [self.currentString setString:@""];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.currentString appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    NSString *value = [self.currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (value.length > 0) {
        [self.currentDictionary setObject:value forKey:elementName];
    }
}

@end 