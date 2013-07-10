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
//  FSResponseStream.h
//  fastcgitest
//

//
//  FCResponseStream is used to send the response back to the client

#import <Foundation/Foundation.h>


@interface FCResponseStream : NSObject
@property(assign, nonatomic) BOOL alwaysFlush;

//response header
- (void)writeValue:(NSString*)value forHeader:(NSString*)header;
- (void)writeHeaders:(NSDictionary*)headers;
- (void)sortAndWriteHeaders:(NSDictionary*)headers;
- (void)writeHeadersForCacheDuration:(NSUInteger)seconds;

//reponse content
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (void)writeString:(NSString*)value;
- (void)writeStringWithFormat:(NSString*)format, ...;
- (void)writeData:(NSData*)data;

- (void)flush;
@end
