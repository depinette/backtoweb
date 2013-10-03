

#import <Foundation/Foundation.h>

@interface FCURLRequest : NSObject

- (NSInputStream *)HTTPBodyStream;
- (NSData *)HTTPBody;

- (NSString *)valueForHTTPHeaderField:(NSString *)field;
- (NSDictionary *)allHTTPHeaderFields;

- (id)valueForFormField:(NSString*)field;
- (NSDictionary*)allFormFields;

- (NSString *)HTTPMethod;

- (NSURL *)URL;

@end
