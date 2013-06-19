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
//  NSURLRequest+Test.m
//  fastcgitest
//

//
//

#import "FCURLRequest.h"
#import "FCURLRequestPrivate.h"
#import "fastcgi.h"
#import "fcgi_stdio.h"
#import "MultipartMessageHeaderField.h"
#import "MultipartFormDataParser.h"

static NSString* getParam(FCGX_Request *pRequest, NSString* field)
{
    char *pValue = FCGX_GetParam([[field uppercaseString] cStringUsingEncoding:NSASCIIStringEncoding], pRequest->envp);
    if (pValue)
        //TODO check encoding in fastcgi spec
        return [[NSString stringWithCString:pValue encoding:NSUTF8StringEncoding] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return nil;
}

static NSString* getParamNoUnescape(FCGX_Request *pRequest, NSString* field)
{
    char *pValue = FCGX_GetParam([[field uppercaseString] cStringUsingEncoding:NSASCIIStringEncoding], pRequest->envp);
    if (pValue)
        return [NSString stringWithCString:pValue encoding:NSUTF8StringEncoding];
    return nil;
}

//http://www.cocoabuilder.com/archive/cocoa/141109-best-encoding.html
static NSStringEncoding charsetToNSStringEncoding(NSString* charset)
{
    CFStringEncoding cfEncoding;
    
    if(charset)
    {
        cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef) charset);
        
        if(cfEncoding != kCFStringEncodingInvalidId)
        {
            return (NSStringEncoding)CFStringConvertEncodingToNSStringEncoding(cfEncoding);
        }
    }
    return NSUTF8StringEncoding;
}

static NSCharacterSet* querySeparators = nil;

@implementation FCURLRequest
{
    FCGX_Request* fcgiRequest;
    __strong NSURL* url;
    __strong NSMutableData* httpBody;
    __strong NSInputStream *httpBodyStream;
    __strong NSDictionary *postFormParams;
    __strong NSFileHandle* attachementHandle;
}

+(void)load
{
    int ret = FCGX_Init();
    if (ret < 0)
        DDLogError(@"FCGX_Init failed with %d", ret);
}

+ (void)initialize
{
    if (!querySeparators)
        querySeparators = [NSCharacterSet characterSetWithCharactersInString:@"&="];
}

- (id)initWithRequest:(FCGX_Request*)pRequest
{
    ddLogLevel = LOG_LEVEL_VERBOSE;
    NSString* queryString = getParamNoUnescape(pRequest, @"QUERY_STRING");
    NSString* scriptUri   = getParamNoUnescape(pRequest, @"SCRIPT_URI");
    NSString* requestURL = nil;
    BOOL hasQuery = (queryString != nil && [queryString length] > 0);
    
    if (scriptUri != nil && [scriptUri length] > 0)
    {
        requestURL = [[NSString alloc] initWithFormat:@"%@%@%@",  scriptUri, hasQuery?@"?":@"", hasQuery?queryString:@""];
    }
    else
    {
        requestURL = [[NSString alloc] initWithFormat:@"%@%@%@%@",    getParamNoUnescape(pRequest, @"HTTP_HOST"),
                                                                    getParamNoUnescape(pRequest, @"REQUEST_URI"),
                                                                    hasQuery?@"?":@"", hasQuery?queryString:@""];
    }
    if (requestURL)
    {
        if (self = [super init])
        {
            fcgiRequest = pRequest;
            httpBody = nil;
            httpBodyStream = nil;
            postFormParams = nil;
            attachementHandle = nil;
            url = [NSURL URLWithString:requestURL];
        }
        return self;
    }

    //debug
    //fcgiRequest = pRequest;
    //NSLog(@"%@", [self allHTTPHeaderFields]);
    return nil;
}

-(void)dealloc
{
    if (fcgiRequest)
    {
        DDLogVerbose(@"dealloc Request");
        FCGX_Finish_r(fcgiRequest);
        free (fcgiRequest);
        fcgiRequest = NULL;
    }
    
    //remove uploadedfiles
    if (attachementHandle)
    {
        NSString *dirPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%llx", (unsigned long long)self]];
        NSError* error = nil;
        if (NO == [[[NSFileManager alloc] init] removeItemAtPath:dirPath error:&error])
        {
            DDLogError(@"Error %@ while removing folder %@", error, dirPath);
        }
    }

    httpBody = nil;
    httpBodyStream = nil;
    url = nil;
    attachementHandle = nil;
    postFormParams = nil;
}

#pragma mark -
#pragma mark mimic NSURLRequest (NSHTTPURLRequest)

- (NSString *)HTTPMethod;
{
    return [self valueForHTTPHeaderField:@"REQUEST_METHOD"];
}

- (NSURL*)URL
{
    return url;
}
- (NSString *)valueForHTTPHeaderField:(NSString *)field
{
    //TODO ? Content-Type -> CONTENT_TYPE
    if (fcgiRequest)
    {
        return getParam(fcgiRequest, field);
    }
    return nil;
}

- (NSDictionary *)allHTTPHeaderFields
{
    NSMutableDictionary* dict = [NSMutableDictionary new];
   
    if (fcgiRequest)
    {
        FCGX_ParamArray penvp = fcgiRequest->envp;
        while (*penvp != NULL)
        {
            //NSLog(@"->%s", *penvp);
            NSString* param = [[NSString stringWithCString:*penvp encoding:NSUTF8StringEncoding] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSRange rangeSeparator = [param rangeOfString:@"="];
            [dict setValue:[param substringFromIndex:rangeSeparator.location+1]
                    forKey:[param substringToIndex:rangeSeparator.location]];
            penvp++;
        }
    }
    return dict;
}
#define GETSTR_BUF_SIZE 1024
- (NSData *)HTTPBody
{
    //in stream
    if (httpBodyStream)
        DDLogError(@"Cannot have stream access and whole body access");
    if (!httpBody && !httpBodyStream)
    {
        char buf[GETSTR_BUF_SIZE];
        if (fcgiRequest)
        {
            httpBody = [NSMutableData dataWithCapacity:GETSTR_BUF_SIZE*4];
            int bytesRead = GETSTR_BUF_SIZE;
            while (bytesRead == GETSTR_BUF_SIZE)
            {
                bytesRead = FCGX_GetStr(buf, GETSTR_BUF_SIZE, fcgiRequest->in);
                [httpBody appendBytes:buf length:bytesRead];
            }
            //return data;
        }
    }
    return httpBody;
}

- (NSInputStream *)HTTPBodyStream;
{
    //TODO  contentLength = [contentLengthStr intValue];
//    TODO body stream for big data ?
    if (httpBody)
        DDLogError(@"Cannot have stream access and whole body access");
    if (!httpBody && !httpBodyStream)
    {
        httpBodyStream = [[FCBodyStream alloc] initWithStream:fcgiRequest->in];
    }
    return httpBodyStream;
}

#pragma mark -
#pragma mark private

+(FCURLRequest*)waitForNextIncomingRequest
{
    FCGX_Request *pRequest = malloc(sizeof(FCGX_Request));
    FCGX_InitRequest(pRequest, FCGI_LISTENSOCK_FILENO, 0);
    
    //blocking call
    int ret = FCGX_Accept_r(pRequest);
    if (ret < 0)
    {
        DDLogError(@"FCGX_Accept_r failed with return %d", ret);
        free(pRequest);
        return nil;
    }
    
    FCURLRequest* newRequest = [[FCURLRequest alloc] initWithRequest:pRequest];
    return newRequest;
}

-(FCGX_Stream*)outStream
{
    return fcgiRequest->out;
}


#pragma mark -
#pragma mark Form Support

- (NSString*)valueForFormField:(NSString*)field
{
    NSDictionary* dico = [self allFormFieldsWithEncoding:NSUTF8StringEncoding];
    return [dico valueForKey:field];
}

- (NSDictionary*)allFormFields
{
    return [self allFormFieldsWithEncoding:NSUTF8StringEncoding];
}

- (NSDictionary*)allFormFieldsWithEncoding:(NSStringEncoding)encoding
{
    if (postFormParams)
        return postFormParams;
    //formfields are either in the QUERY_STRING fcgi var or in the body (POST with application/x-www-form-urlencoded)
    //or in the body with multipart/form-data
char *pValue = FCGX_GetParam([@"CONTENT_TYPE" cStringUsingEncoding:NSASCIIStringEncoding], fcgiRequest->envp);
    MultipartMessageHeaderField* field = pValue?[[MultipartMessageHeaderField alloc] initWithValue:[NSData dataWithBytesNoCopy:pValue length:strlen(pValue) freeWhenDone:NO]
                                                                                   contentEncoding:NSASCIIStringEncoding]:nil;
    //URL encoded in the body
    if (field && [field.value hasPrefix:@"multipart/form-data"])
    {
#define FORMDATA_BUFFER_SIZE (16*1024)
        MultipartFormDataParser* parser = [[MultipartFormDataParser alloc] initWithBoundary:[field.params valueForKey:@"boundary"]
                                                                               formEncoding:encoding];
        parser.delegate = self;
        postFormParams = [NSMutableDictionary dictionaryWithCapacity:1];
        NSInputStream* inputStream = [self HTTPBodyStream];
        uint8_t* bytes = malloc(FORMDATA_BUFFER_SIZE);
        NSData* data = [[NSData alloc] initWithBytesNoCopy:bytes length:FORMDATA_BUFFER_SIZE freeWhenDone:NO];
        while ([inputStream hasBytesAvailable])
        {
            [inputStream read:bytes maxLength:FORMDATA_BUFFER_SIZE];
            [parser appendData:data];
        }
        free(bytes);
    }
    else
    {
        NSString *queryString = nil;
        if (field && [field.value hasPrefix:@"application/x-www-form-urlencoded"])
        {
            //no charset= parameter in the content-type, so the encoding should be specified in a hidden field
            queryString = [[NSString alloc] initWithData:[self HTTPBody] encoding:NSASCIIStringEncoding];
        }
        else
            queryString = getParamNoUnescape(fcgiRequest, @"QUERY_STRING");
        
        if (queryString)
        {
            NSArray *keysvalues = [queryString componentsSeparatedByCharactersInSet:querySeparators];
            NSUInteger nbKeys = keysvalues.count/2;
            if (keysvalues && nbKeys > 0 && nbKeys*2 == keysvalues.count)
            {
                postFormParams = [NSMutableDictionary dictionaryWithCapacity:nbKeys];
                for (NSUInteger i=0; i < nbKeys; i++)
                {
                    [postFormParams setValue:[[keysvalues objectAtIndex:2*i+1] stringByReplacingPercentEscapesUsingEncoding:encoding]
                                      forKey:[[keysvalues objectAtIndex:2*i] stringByReplacingPercentEscapesUsingEncoding:encoding]];
                }
            }
        }
    }
    
    return postFormParams;
}

#pragma mark-
#pragma mark multipartformDataParser delegate
- (void) multipartFormDataParser:(MultipartFormDataParser*)parser processStartOfPartWithHeader:(MultipartMessageHeader*) header
{
    MultipartMessageHeaderField *field = [header.fields valueForKey:@"Content-Disposition"];
    if (field)
    {
        NSString* filename = [field.params valueForKey:@"filename"];
        if (filename && filename.length)
        {
            NSString *contentType = [[header.fields valueForKey:@"Content-Type"] value];
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%llx", (unsigned long long)self]];
            NSError *error = nil;

            if ([fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error])
            {
                filePath = [filePath stringByAppendingPathComponent:filename];
                if ([fileManager createFileAtPath:filePath contents:nil attributes:nil])
                {
                    attachementHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
                    if (attachementHandle)
                    {
                        NSString* name = [field.params valueForKey:@"name"];
                        [postFormParams setValue:filePath forKey:name];
                        DDLogInfo(@"Attachement file opened for write:%@", filePath);
                        if (contentType)
                            [postFormParams setValue:contentType forKey:[name stringByAppendingString:@"$Content-Type"]];
                    }
                }
                if (nil == attachementHandle)
                    DDLogError(@"Error while creating file %@", filePath);    
            }
            else
            {
                DDLogError(@"Error %@ while creating directory %@", error, filePath);
            }
        }
    }
}

- (void) multipartFormDataParser:(MultipartFormDataParser*)parser processContent:(NSData*) data WithHeader:(MultipartMessageHeader*) header
{
    if (attachementHandle)
    {
        [attachementHandle writeData:data];
    }
    else
    {
        MultipartMessageHeaderField *field = [header.fields valueForKey:@"Content-Disposition"];
        if (field)
        {
            NSStringEncoding encoding = parser.formEncoding;
            NSString* charset = [field.params valueForKey:@"charset"];
            if (charset)
                encoding = charsetToNSStringEncoding(charset);
            
            NSString* name = [field.params valueForKey:@"name"];
            NSString* value = [postFormParams valueForKey:name];
            NSString* dataAsString = [[NSString alloc] initWithData:data encoding:encoding];
            if (value)
                [postFormParams setValue:[value stringByAppendingString:dataAsString] forKey:name];
            else
                [postFormParams setValue:dataAsString forKey:name];
        }
    }
}

- (void) multipartFormDataParser:(MultipartFormDataParser*)parser processEndOfPartWithHeader:(MultipartMessageHeader*) header
{
    if (attachementHandle)
    {
        [attachementHandle closeFile];
        //attachementHandle = nil;
    }
}

@end



@implementation FCBodyStream

-(id)initWithStream:(FCGX_Stream*)fastCgiInStream
{
    if (self = [super init])
    {
        inStream = fastCgiInStream;
    }
    return self;
}

// reads up to length bytes into the supplied buffer, which must be at least of size len. Returns the actual number of bytes read.
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    assert(len <= INT_MAX);
    if (len <= INT_MAX)
        return FCGX_GetStr((char*)buffer, (int)len, inStream);
    else
        DDLogError(@"len (%ld) superior to INT_MAX (%d)", len, INT_MAX);
    return 0;
}

// returns in O(1) a pointer to the buffer in 'buffer' and by reference in 'len' how many bytes are available.
//This buffer is only valid until the next stream operation. Subclassers may return NO for this if it is not appropriate for the stream type.
//This may return NO if the buffer is not available.
- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
    return NO;
}

// returns YES if the stream has bytes available or if it impossible to tell without actually doing the read.
- (BOOL)hasBytesAvailable
{
    return (FCGX_HasSeenEOF(inStream) == 0); //EOF if end-of-file has been detected, 0 if not.
}


- (void)open
{
    
}
- (void)close
{
    
}

- (id <NSStreamDelegate>)delegate
{
    return delegate;
}
- (void)setDelegate:(id <NSStreamDelegate>)theDelegate;
{
    if (theDelegate)
        delegate = theDelegate;
    else
        delegate = self;
}

- (id)propertyForKey:(NSString *)key;
{
    DDLogError(@"propertyForKey: not implemented");
    return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key;
{
    DDLogError(@"setProperty:forKey: not implemented");
    return NO;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    DDLogError(@"scheduleInRunLoop:forMode: not implemented");
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    DDLogError(@"removeFromRunLoop:forMode: not implemented");
}

- (NSStreamStatus)streamStatus
{
    int iError = FCGX_GetError(inStream);
    if (iError == 0)
    {
        if ([self hasBytesAvailable])
            return NSStreamStatusOpen;
        else
            return NSStreamStatusAtEnd;
    }
    else
        return NSStreamStatusError;
}


//      Return the stream error code.  0 means no error, > 0
//      is an errno(2) error, < 0 is an FCGX_errno error.
- (NSError *)streamError
{
    /*
FCGX_UNSUPPORTED_VERSION -2
FCGX_PROTOCOL_ERROR -3
FCGX_PARAMS_ERROR -4
FCGX_CALL_SEQ_ERROR -5
    */
    int iError = FCGX_GetError(inStream);
    if (iError != 0)
    {
        NSError *error = [NSError errorWithDomain:@"com.depsys.b2wapp" code:iError userInfo:nil];
        return error;
    }
    return nil;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    DDLogVerbose(@"stream:handleEvent:%d", (int)eventCode);
}

@end

