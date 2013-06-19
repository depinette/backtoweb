#import <Foundation/Foundation.h>

@interface NSData (DDData)

- (NSData *)md5Digest;

- (NSData *)sha1Digest;

- (NSString *)hexStringValue;

- (NSString *)base64Encoded;
- (NSData *)base64Decoded;

- (NSData *)base64DecodedWithRFC4648:(BOOL)useRFC4648;
- (NSString *)base64EncodedWithRFC4648:(BOOL)useRFC4648;

@end

