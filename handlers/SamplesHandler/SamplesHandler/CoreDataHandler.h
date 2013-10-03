//
//  CoreDataHandler.h
//  SamplesHandler
//
//  Created by depsys on 24/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CoreDataHandler : NSObject <FCRequestHandler>

@end

static NSString * const kURLKeyMethod       = @"method";
static NSString * const kURLKeyMethodGet    = @"get";
static NSString * const kURLKeyMethodSet    = @"set";
static NSString * const kURLKeyMethodNew    = @"new";
static NSString * const kURLKeyMessage      = @"message";
static NSString * const kURLKeyFrom         = @"from";
static NSString * const kURLKeyNumber       = @"nb";
static NSString * const kItemKeyEntity      = @"Item";
static NSString * const kItemKeyId          = @"id";
static NSString * const kItemKeyMessage     = @"message";
static NSString * const kItemKeyDate        = @"date";
static NSString * const kItemKeyMaxId       = @"maxId";
static NSString * const kJSONKeyId          = @"id";
static NSString * const kJSONKeyItem        = @"message";
static NSString * const kJSONKeyItems       = @"messages";
static NSString * const kJSONKeyMessage     = @"message";
static NSString * const kJSONStatus         = @"status";
static NSString * const kJSONDate           = @"lastModified";