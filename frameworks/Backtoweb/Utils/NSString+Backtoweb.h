//
//  NSString+Base36.h
//  
//
//  Created by depsys on 04/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Backtoweb)
+(NSString*) formatNumber:(NSUInteger)n usingAlphabet:(NSString*)alphabet;
- (NSUInteger)numberUsingAlphabet:(NSString*)alphabet;
+(NSString*) formatNumber:(NSUInteger)n toBase:(NSUInteger)base;
@end
