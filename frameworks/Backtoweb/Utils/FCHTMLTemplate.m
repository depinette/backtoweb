//
//  FCHTMLTemplate.m
//  Backtoweb
//
//  Created by depsys on 04/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import "FCHTMLTemplate.h"
#import "FCResponseStream.h"
#import <Lumberjack/Lumberjack.h>

static int ddLogLevel = LOG_LEVEL_WARN;

@implementation FCHTMLTemplate
{
    __strong NSMutableArray* ranges;
    __strong NSString* html;
}

#pragma mark - inits

- (id)initWithHTMLString:(NSString*)htmlTemplate
{
    if (self = [super init])
    {
        html = htmlTemplate;
    }
    return self;
}
- (id)initWithHTMLFile:(NSString*)filepath;
{
    if (self = [super init])
    {
        NSError* error = nil;
        html = [[NSString alloc] initWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:&error];
        if (!html)
        {
            DDLogError(@"Error while reading file %@: %@", filepath, error);
            return nil;
        }
    }
    return self;
}

#pragma mark - internal

#define LEFT_BRACE @"{{"
#define RIGHT_BRACE @"}}"
#define SIZE_LEFT_BRACE 2
#define SIZE_RIGHT_BRACE 2
- (void)enumerateVariables
{
    ranges = [[NSMutableArray alloc] initWithCapacity:10];
    NSRange nextVariable = [html rangeOfString:LEFT_BRACE];
    while (nextVariable.location != NSNotFound)
    {
        NSRange end = [html rangeOfString:RIGHT_BRACE options:NSLiteralSearch range:NSMakeRange(nextVariable.location+SIZE_LEFT_BRACE, html.length - (nextVariable.location+SIZE_RIGHT_BRACE))];
        if (end.location == NSNotFound)
            break;
        
        [ranges addObject:[NSValue valueWithRange:NSMakeRange(nextVariable.location, end.location+end.length-nextVariable.location)]];
        nextVariable = [html rangeOfString:LEFT_BRACE options:NSLiteralSearch range:NSMakeRange(end.location+SIZE_RIGHT_BRACE, html.length - (end.location+SIZE_RIGHT_BRACE))];
    }
}

- (NSString*)keyForRange:(NSRange)range
{
    return [html substringWithRange:NSMakeRange(range.location+SIZE_LEFT_BRACE, range.length-(SIZE_LEFT_BRACE+SIZE_RIGHT_BRACE))];
}

#pragma mark - public

- (void)writeToStream:(FCResponseStream*)responseStream usingValues:(NSObject/*<NSKeyValueCoding>*/*)values;
{
    if (!ranges)
        [self enumerateVariables];
    
    NSUInteger currentPosition = 0;
    for (int i = 0; i < ranges.count; i++)
    {
        NSRange range = [[ranges objectAtIndex:i] rangeValue];

        [responseStream writeString:[html substringWithRange:NSMakeRange(currentPosition, range.location-currentPosition)]];
        
        NSString* key = [self keyForRange:range];
        NSString* value = [values valueForKey:key];
        if (value)
        {
            [responseStream writeString:value];
        }
        else
        {
            DDLogError(@"Error value %@%@%@ not found in template", LEFT_BRACE, key, RIGHT_BRACE);
        }
        currentPosition = range.location+range.length;
    }
    [responseStream writeString:[html substringWithRange:NSMakeRange(currentPosition, html.length-currentPosition)]];
}

@end
