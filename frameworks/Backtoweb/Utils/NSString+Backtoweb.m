//
//  NSString+Base36.m
//  Backtoweb
//
//  Created by depsys on 04/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import "NSString+Backtoweb.h"

@implementation NSString (Backtoweb)


//http://stackoverflow.com/questions/14780246/base-62-conversion-in-objective-c?lq=1
// Uses the alphabet length as base.
+(NSString*) formatNumber:(NSUInteger)n usingAlphabet:(NSString*)alphabet
{
    NSUInteger base = [alphabet length];
    if (n<base){
        // direct conversion
        NSRange range = NSMakeRange(n, 1);
        return [alphabet substringWithRange:range];
    } else {
        return [NSString stringWithFormat:@"%@%@",
                
                // Get the number minus the last digit and do a recursive call.
                // Note that division between integer drops the decimals, eg: 769/10 = 76
                [self formatNumber:n/base usingAlphabet:alphabet],
                
                // Get the last digit and perform direct conversion with the result.
                [alphabet substringWithRange:NSMakeRange(n%base, 1)]];
    }
}

- (NSUInteger)numberUsingAlphabet:(NSString*)alphabet
{
    NSUInteger result = 0;
    NSUInteger base = [alphabet length];
    NSUInteger length = self.length;
    for (NSInteger i = 0; i < length; i++)
    {
        for (int j = 0; j < base; j++)
        {
            if ([alphabet characterAtIndex:j] == [self characterAtIndex:i])
                result += j*pow(base, length-1-i);
        }
    }
    
    return result;
}

+(NSString*) formatNumber:(NSUInteger)n toBase:(NSUInteger)base
{
    NSString *alphabet = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"; // 62 digits
    NSAssert([alphabet length]>=base,@"Not enough characters. Use base %ld or lower.",(unsigned long)[alphabet length]);
    return [self formatNumber:n usingAlphabet:[alphabet substringWithRange:NSMakeRange (0, base)]];
}

@end
