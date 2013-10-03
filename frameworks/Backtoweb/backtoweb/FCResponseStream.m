/***********************************************************************************
 * This software is under the MIT License quoted below:
 ***********************************************************************************
 *
 * Copyright (c) 2013 David Epinette
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/
//  FSResponseStream.m

static int ddLogLevel = LOG_LEVEL_WARN;

//TODO TEST
//- (void)writeHeaders:(NSDictionary*)headers
//- (void)sortAndWriteHeaders:(NSDictionary*)headers

#import "FCResponseStream.h"
#import "fcgiapp.h"
#import "FCURLRequest.h"
#import "FCURLRequestPrivate.h"

@implementation FCResponseStream
{
    FCGX_Stream* outStream;
    __strong FCURLRequest* request;
    struct __flags
    {
        unsigned int        sendingContent:1;
        unsigned int        contentTypeDone:1;
    }  _flags;
}

@synthesize alwaysFlush = _alwaysFlush;

#pragma mark -
#pragma mark init/dealloc
-(id)initWithRequest:(FCURLRequest*)theRequest
{
    if (self = [super init])
    {
        outStream = [theRequest outStream];
        request = theRequest;
        _flags.sendingContent = NO;
        _flags.contentTypeDone = NO;
    }
    return self;
}

- (void)dealloc
{
    request = nil;
}

#pragma mark -
#pragma mark public
- (void)flush
{
    FCGX_FFlush(outStream);
}

- (void)writeValue:(NSString*)value forHeader:(NSString*)header
{
    if (_flags.sendingContent == YES)
        DDLogError(@"Too late for headers, content has been written (%@: %@)", header, value);
    else
    {
        if (_flags.contentTypeDone == NO && NSOrderedSame == [header caseInsensitiveCompare:@"Content-Type"])
            _flags.contentTypeDone = YES;
        const char* buf = [header UTF8String];
        int ret = FCGX_PutStr(buf, (int)strlen(buf), outStream);
        if (ret>0) ret = FCGX_PutStr(": ", 2, outStream);
        buf = [value UTF8String];
        if (ret>0) ret = FCGX_PutStr(buf, (int)strlen(buf), outStream);
        if (ret>0) ret = FCGX_PutStr("\r\n", 2, outStream);
        if (ret < 0)
        {
            DDLogError(@"FCGX_PutStr error %d", ret);
        }
    }
}

- (void)writeHeaders:(NSDictionary*)headers
{
    //enumerate with block (faster it seems : http://stackoverflow.com/questions/1284429/is-there-a-way-to-iterate-over-a-dictionary/ )
    [headers enumerateKeysAndObjectsUsingBlock:^(id header, id value, BOOL *stop)
    {
        [self writeValue:value forHeader:header];
        *stop = NO;
    }];
}

//write Cache-Control + Expires headers
//http://blog.mro.name/2009/08/nsdateformatter-http-header/
-(void)writeHeadersForCacheDuration:(NSUInteger)seconds
{
    static NSDateFormatter *dateFormatter = nil;
    [self writeValue:[NSString stringWithFormat:@"max-age=%lu", seconds] forHeader:@"Cache-Control"];
    if(dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] ;
        dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        dateFormatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    }
    [self writeValue:[dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:seconds]] forHeader:@"Expires"];
}

static NSArray* orderedHeaders = nil;
static const int nborderedHeaders = 28;
//sort Headers according to "good practice" in spec
//http://stackoverflow.com/questions/11197693/is-the-order-of-webrequest-headers-important
- (void)sortAndWriteHeaders:(NSDictionary*)headers
{
    if (orderedHeaders == nil)
    {
        orderedHeaders = @[
          @"Cache-Control", @"Connection", @"Date", @"Pragma", @"Trailer", @"Transfer-Encoding", @"Upgrade", @"Via", @"Warning",
          @"Accept-Ranges", @"Age", @"ETag", @"Location", @"Proxy-Authenticate", @"Retry-After", @"Server", @"Vary", @"WWW-Authenticate",
          @"Allow", @"Content-Encoding", @"Content-Language", @"Content-Length", @"Content-Location", @"Content-MD5", @"Content-Range", @"Content-Type", @"Expires", @"Last-Modified"
        ];
    }
    
    //TODO is it fast ?
    NSMutableDictionary* tempHeaders = [headers mutableCopy];
    [orderedHeaders enumerateObjectsUsingBlock:^(id header, NSUInteger idx, BOOL *stop)
    {
        NSString *value = [tempHeaders valueForKey:header];
        if (value)
            [self writeValue:value forHeader:header];
    }];
    [tempHeaders removeObjectsForKeys:orderedHeaders];
    [self writeHeaders:tempHeaders];
}

- (void)writeString:(NSString*)value
{
    if (value)
    {
        const char* buf = [value UTF8String];
        [self write:(uint8_t*)buf maxLength:strlen(buf)];
    }
}

- (void)writeStringWithFormat:(NSString *)format, ...
{
    va_list args;
    if (format)
    {
		va_start(args, format);
		
        const char* buf = [[[NSString alloc] initWithFormat:format arguments:args] UTF8String];
        [self write:(uint8_t*)buf maxLength:strlen(buf)];
        
		va_end(args);
    }
}

- (void)writeData:(NSData*)data
{
    [self write:[data bytes] maxLength:[data length]];
}

#pragma mark NSOutputStream override
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len
{
    assert(len <= INT_MAX); //please write less than INT_MAX bytes
    if (_flags.sendingContent == NO)
    {
        if (_flags.contentTypeDone == NO)
        {
            DDLogWarn(@"Warning no headers written, writing Content-Type text/html");
            [self writeValue:@"text/html" forHeader:@"Content-type"];
        }
        _flags.sendingContent = YES;
        [self writeString:@"\r\n"];
    }
    
    int ret = FCGX_PutStr((const char*)buffer,(int)len, outStream);
    if (ret < 0)
    {
        DDLogError(@"FCGX_PutStr error %d", ret);
    }
    if (_alwaysFlush == YES)
    {
        FCGX_FFlush(outStream);
    }
    
    return ret;
}

- (BOOL)hasSpaceAvailable
{
    return YES;
}

- (NSStreamStatus)streamStatus
{
    NSStreamStatus status = NSStreamStatusError;
    int error = FCGX_GetError(outStream);
    switch(error)
    {
        case 0:
            status = NSStreamStatusOpen;
            break;
        default:
        case FCGX_UNSUPPORTED_VERSION:
        case FCGX_PROTOCOL_ERROR:
        case FCGX_PARAMS_ERROR:
        case FCGX_CALL_SEQ_ERROR:
            status = NSStreamStatusError;
            break;
    };
    return status;
}
- (NSError*)streamError
{
    int error = FCGX_GetError(outStream);
    if (error == 0)
        return nil;
    return[NSError errorWithDomain:@"backtoweb" code:error userInfo:nil];
}
#pragma mark -
@end
