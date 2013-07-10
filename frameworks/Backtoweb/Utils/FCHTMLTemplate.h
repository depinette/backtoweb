//
//  FCHTMLTemplate.h
//  Backtoweb
//
//  Created by depsys on 04/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FCResponseStream;
@interface FCHTMLTemplate : NSObject
- (id)initWithHTMLString:(NSString*)htmlTemplate;
- (id)initWithHTMLFile:(NSString*)filepath;

- (void)writeToStream:(FCResponseStream*)responseStream usingValues:(NSObject/*<NSKeyValueCoding>*/*)values;

@end
