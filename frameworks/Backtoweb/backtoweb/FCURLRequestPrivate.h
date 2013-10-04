

#import <Foundation/Foundation.h>
#import "MultipartFormDataParser.h"
#import "fcgiapp.h"

@interface FCURLRequest (Private)
+(FCURLRequest*)waitForNextIncomingRequest;
- (id)initWithRequest:(FCGX_Request*)pRequest;
- (FCGX_Stream*)outStream;
+(void)cancelWaitingRequest;
@end

@protocol MultipartFormDataParserDelegate;
@interface FCURLRequest (Form) <MultipartFormDataParserDelegate>

@end

@interface FCBodyStream : NSInputStream<NSStreamDelegate>
{
    FCGX_Stream* inStream;
    __weak id <NSStreamDelegate> delegate;
}

-(id)initWithStream:(FCGX_Stream*)fastCgiInStream;
@end