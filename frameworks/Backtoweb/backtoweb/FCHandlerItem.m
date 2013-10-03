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
//  FCHandlerItem.m
//

static int ddLogLevel = LOG_LEVEL_WARN;

#import "FCHandlerItemPrivate.h"
#import "FCURLRequest.h"
#import "FCResponseStream.h"

@interface FCHandlerItem ()
-(void)setupWithRule:(NSString*)aRule ruleType:(FCRuleType)theRuleType pathType:(FCPathType)thePathType handlerBlock:(REQUEST_HANDLER_BLOCK)theBlock andPriority:(FCHandlerPriority)thePriority;
@property (nonatomic, strong) NSRegularExpression* regex;
@end


@implementation FCHandlerItem
{
    __strong NSString* rule;
    __strong REQUEST_HANDLER_BLOCK handlerBlock;
    NSUInteger ruleType;
    FCPathType pathType;
    
}
@synthesize regex, priority;
-(id)initWithRule:(NSString*)aRule ruleType:(NSUInteger)theRuleType pathType:(FCPathType)thePathType handlerBlock:(REQUEST_HANDLER_BLOCK)theBlock andPriority:(FCHandlerPriority)thePriority
{
    if (self = [super init])
    {
        [self setupWithRule:aRule ruleType:theRuleType pathType:thePathType handlerBlock:theBlock andPriority:thePriority ];
    }
    
    return self;
}

-(id)initWithBlock:(REQUEST_HANDLER_BLOCK)theBlock andPriority:(FCHandlerPriority)thePriority
{
    if (self = [super init])
    {
        [self setupWithRule:nil ruleType:FCRuleTypeNone pathType:FCPathTypeNone handlerBlock:theBlock andPriority:thePriority];
    }
    return self;
}

-(void)setupWithRule:(NSString*)aRule ruleType:(FCRuleType)theRuleType pathType:(FCPathType)thePathType handlerBlock:(REQUEST_HANDLER_BLOCK)theBlock andPriority:(FCHandlerPriority)thePriority
{
    rule = aRule;
    ruleType = theRuleType;
    handlerBlock = theBlock;
    pathType = thePathType;
    self.priority = thePriority;
    regex = nil;
}

-(void)dealloc
{
    DDLogVerbose(@"FCHandlerItem dealloc");
}

-(NSRegularExpression*)regex
{
    if (!regex)
    {
        NSError *error = NULL;
        regex = [[NSRegularExpression alloc] initWithPattern:rule
                                                     options:NSRegularExpressionCaseInsensitive
                                                       error:&error];
        if (!regex)
        {
            if (error)
                DDLogError(@"Regex Error : %@ for %@", error, rule);
            else
                DDLogError(@"Unknown regex error");
        }
    }
    return regex;
}

-(BOOL)respondsToRequest:(FCURLRequest*)request
{
    __block BOOL bRulePassed = NO;
    
    if (ruleType == FCRuleTypeNone)
    {
        bRulePassed = YES;
    }
    else
    {
        @try
        {
            NSString* urlString = nil;
            switch (pathType)
            {
                default:
                    assert(0);
                case FCPathTypeSystem:
                {
                    NSString* docRoot = [request valueForHTTPHeaderField:@"DOCUMENT_ROOT"];
                    urlString = [docRoot stringByAppendingPathComponent:request.URL.path];
                    break;
                }
                case FCPathTypeURLPath:
                {
                    urlString = request.URL.path;
                    break;
                }
            }
            if (ruleType == FCRuleTypeRegex && rule)
            {
                if (self.regex)
                {
                    NSRange range = NSMakeRange(0, [urlString length]);
                    [self.regex enumerateMatchesInString:urlString options:0 range:range
                                              usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
                    {
                        if (NSEqualRanges(range, result.range))
                        {
                            bRulePassed = YES;
                            *stop = YES;
                        }
                    }];
                        
                }
            }
            else if (ruleType == FCRuleTypeLiteral && rule)
            {
                bRulePassed = ([rule caseInsensitiveCompare:urlString] == NSOrderedSame);
            }
        }
        @catch (NSException * e) {
            DDLogError(@"Exception: %@", e);
            e = nil;
        }
        @catch (...)
        {
            DDLogError(@"Unknown exception");
        }
        @finally
        {
            
        }
    }
    DDLogVerbose(@"Rule %@ (type=%lu) %@", rule, ruleType, bRulePassed?@"passed":@"not passed");
    
    return bRulePassed;
}

-(BOOL)handleRequest:(FCURLRequest*)request response:(FCResponseStream*)responseStream context:(NSMutableDictionary*)context
{
    BOOL nextHandler = YES;
    DDLogVerbose(@"calling handler %@", [request.URL absoluteString]);
    
    @try
    {
        nextHandler = handlerBlock(request, responseStream, context);
    }
    @catch (NSException * e) {
        DDLogError(@"Exception: %@", e);
        [responseStream writeValue:@"text/html" forHeader:@"Content-type"];
        [responseStream writeStringWithFormat:@"exception:%@", e.description];
        [responseStream flush];
        e = nil;
    }
    @catch (...)
    {
        DDLogError(@"Unknown exception");
        [responseStream writeString:@"Unknwon exception"];
    }
    @finally
    {
        
    }
    return nextHandler;
}

@end
