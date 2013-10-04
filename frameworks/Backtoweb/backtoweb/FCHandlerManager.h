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
//  FCHandlerManager.h
//  fastcgitest
//

//
//

#import <Foundation/Foundation.h>
#import "FCHandlerItemProtocol.h"

typedef BOOL (^REQUEST_HANDLER_BLOCK)(FCURLRequest* request, FCResponseStream *responseStream, NSMutableDictionary* context);

//
enum {
    FCRuleTypeNone = 0,
    FCRuleTypeLiteral,   /* the request path must be equal to the rule string (case insensitive) */
    FCRuleTypeRegex,     /* the request path must match the regex define in the rule string */
};
typedef NSUInteger FCRuleType;

//Path to match in rule matching (local filesystem, url path)
enum {
    FCPathTypeNone=0,
    FCPathTypeSystem,    /* Test the rule against the local filesystem path : <DOCUMENT_ROOT>/path */
    FCPathTypeURLPath,   /* Test the rule against the local URL path (without the HOST part) : /path */
    //    FCPathTypeURLFull, //TODO include host
};
typedef NSUInteger FCPathType;

@interface FCHandlerManager : NSObject
- (void)addHandler:(REQUEST_HANDLER_BLOCK)block priority:(FCHandlerPriority)priority;
- (void)addHandler:(REQUEST_HANDLER_BLOCK)block forRegexPath:(NSString*)regexPath pathType:(FCPathType)pathType priority:(FCHandlerPriority)priority;
- (void)addHandler:(REQUEST_HANDLER_BLOCK)block forLiteralPath:(NSString*)literalPath pathType:(FCPathType)pathType priority:(FCHandlerPriority)priority;
- (void)addHandlerItem:(id<FCHandlerItemProtocol>)handlerItem;
-(BOOL)hasHandler:(id)handlerItem;
- (void)removeHandler:(id)handlerItem;
@end
