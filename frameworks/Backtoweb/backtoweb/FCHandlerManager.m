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
//  FCHandlerManager.m
//  fastcgitest
//

//
//thread safe classes
//https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html

static int ddLogLevel = LOG_LEVEL_WARN;

#import "FCHandlerManager.h"
#import "FCHandlerManagerPrivate.h"
#import <objc/runtime.h>
#import "FCHandlerItemPrivate.h"
#import "FCURLRequest.h"
#import "FCURLRequestPrivate.h"
#import "FCResponseStreamPrivate.h"
#import "NSBundle+additions.h"
#import "FCRequestHandlerProtocol.h"

@interface FCHandlerManager()
@property(nonatomic, strong) NSMutableArray* requestHandlers;
@end


@implementation FCHandlerManager
{
    __strong NSLock* handlersLock;
    Class *handlerClasses;
}
@synthesize requestHandlers;

+(FCHandlerManager*)sharedInstance
{
    static FCHandlerManager* sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sharedInstance = [[FCHandlerManager alloc] init]; });
    return sharedInstance;
}

-(id)init
{
    if (self = [super init])
    {
        self.requestHandlers = [NSMutableArray array];
        handlersLock = [[NSLock alloc] init];
        handlerClasses = NULL;
    }
    return self;
}

-(void)dealloc
{
    if (handlerClasses)
        free(handlerClasses);
}


-(void)findAndRegisterHandlers
{
    int numClasses;
    Class *allClasses = NULL;
    
    if (handlerClasses)
    {
        free(handlerClasses);
        handlerClasses = NULL;
    }

    numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0 )
    {
        allClasses = (Class*)malloc(sizeof(Class) * numClasses);
        handlerClasses = (Class*)malloc(sizeof(Class) * numClasses);
        memset(handlerClasses, (int)NULL, sizeof(Class) * numClasses);
        numClasses = objc_getClassList(allClasses, numClasses);
        int numHandlerClass = 0;
        for (int index = 0; index < numClasses; index++)
        {
            Class nextClass = allClasses[index];
            if (class_conformsToProtocol(nextClass, @protocol(FCRequestHandler)))
            {
                //found a tagged class
                if (NULL != class_getClassMethod(nextClass, @selector(initializeHandlers:)))
                {
                    handlerClasses[numHandlerClass] = nextClass;
                    numHandlerClass++;
                }
                else
                {
                    DDLogError(@"%s does not responds to initializeHandlers:", class_getName(nextClass));
                }
            }
        }
        free(allClasses);
        
        //sort by class names, so that we can rely on some kind of order for request handling
        for (int i = 0; i < numHandlerClass-1; i++)
        {
            for (int j = i+1; j < numHandlerClass; j++)
            {
                NSString* name1 = NSStringFromClass(handlerClasses[i]);
                NSString* name2 = NSStringFromClass(handlerClasses[j]);
                if ([name1 localizedCaseInsensitiveCompare:name2] == NSOrderedDescending)
                {
                    Class temp = handlerClasses[i];
                    handlerClasses[i] = handlerClasses[j];
                    handlerClasses[j] = temp;
                }
            }
        }
        
        //remove existing handlers
        [handlersLock lock];
        [self.requestHandlers removeAllObjects];
        [handlersLock unlock];
        
        //let the request handler register their handler block
        for (int i = 0; i < numHandlerClass; i++)
        {
            DDLogVerbose(@"handler class %@",  NSStringFromClass(handlerClasses[i]));
            [handlerClasses[i] initializeHandlers:self];
        }
    }
}

- (void)willTerminate
{
    DDLogVerbose(@"willTerminate0");
    
    if (handlerClasses)
    {
        Class *nextClass = handlerClasses;
        if (nextClass != NULL && NULL != class_getClassMethod(*nextClass, @selector(willTerminate:)))
            [*nextClass willTerminate];
    }
}
#pragma mark -
#pragma mark Handler bundle management

-(void)loadHandlerBundles:(NSString*)path
{
    NSFileManager* localFileManager = [NSFileManager new];
    
    NSDirectoryEnumerator *dirEnum = [localFileManager enumeratorAtURL:[NSURL fileURLWithPath:path] includingPropertiesForKeys:[NSArray array] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
          errorHandler:^BOOL(NSURL *url, NSError *error)
          {
              if (error != nil)
              {
                  DDLogError(@"Error %@ while enumerating:%@", error, url);
              }
              return TRUE;
          }];
    
    for (NSURL* url in dirEnum)
    {
        NSString* path = [url path];
        if ([[path pathExtension] isEqualToString:@"bundle"])
        {
            [NSBundle loadBundle:path];
        }
    }
}

#pragma mark -
#pragma mark Handler registrations
-(void)addHandler:(REQUEST_HANDLER_BLOCK)block priority:(FCHandlerPriority)priority
{
    FCHandlerItem* handlerItem = [[FCHandlerItem alloc] initWithBlock:[block copy] andPriority:priority];
    [self addHandlerItem:handlerItem];
}

-(void)addHandler:(REQUEST_HANDLER_BLOCK)block forRegexPath:(NSString*)regexPath pathType:(FCPathType)pathType priority:(FCHandlerPriority)priority
{
    FCHandlerItem* handlerItem = [[FCHandlerItem alloc] initWithRule:regexPath ruleType:FCRuleTypeRegex pathType:pathType handlerBlock:[block copy] andPriority:priority];
    [self addHandlerItem:handlerItem];
}

-(void)addHandler:(REQUEST_HANDLER_BLOCK)block forLiteralPath:(NSString*)literalPath pathType:(FCPathType)pathType priority:(FCHandlerPriority)priority
{
    FCHandlerItem* handlerItem = [[FCHandlerItem alloc] initWithRule:literalPath ruleType:FCRuleTypeLiteral pathType:pathType handlerBlock:[block copy] andPriority:priority];
    [self addHandlerItem:handlerItem];
}

-(void)addHandlerItem:(id<FCHandlerItemProtocol>)handlerItem
{
    [handlersLock lock];
    FCHandlerPriority priority = handlerItem.priority;
    __block NSUInteger index = self.requestHandlers.count;
    [self.requestHandlers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
     {
         //Loop until a lower priority handler is found
         if (((FCHandlerItem*)obj).priority > priority)
         {
             index = idx;
             *stop = YES;
         }
         else
             *stop = NO;
     }];
    DDLogVerbose(@"insertHandler %@ at %lu",handlerItem, index);
    [self.requestHandlers insertObject:handlerItem atIndex:index];
    [handlersLock unlock];
}


-(BOOL)hasHandler:(id)handlerItem
{
    BOOL b = NO;
    [handlersLock lock];
    if ([self.requestHandlers indexOfObject:handlerItem] != NSNotFound)
    {
        b = YES;
    }
    [handlersLock unlock];
    return b;
}

-(void)removeHandler:(id)handlerItem
{
    [handlersLock lock];
    if ([self.requestHandlers indexOfObject:handlerItem] != NSNotFound)
    {
        [self.requestHandlers removeObject:handlerItem];
    }
    handlerItem = nil;
    [handlersLock unlock];
}

/*
-(void)updateHandler:(FCHandlerItem*)handlerItem withBlock:(REQUEST_HANDLER_BLOCK)block
{
    [handlersLock lock];
    if ([self.requestHandlers indexOfObject:handlerItem] != NSNotFound)
    {
        [self.requestHandlers removeObject:handlerItem];
    }
    [handlersLock unlock];
}*/

#pragma mark -
#pragma mark Find the handler
-(void)handleRequest:(FCURLRequest*)request
{
   [handlersLock lock];
    //NSArray is thread safe
   __block NSArray* handlers = [[NSArray alloc] initWithArray:self.requestHandlers];
   [handlersLock unlock];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^
    {
        @autoreleasepool { //http://www.cocoabuilder.com/archive/cocoa/305168-dispatch-queues-and-autorelease-pools.html
            NSUInteger nbHandler = [handlers count];
            DDLogVerbose(@"Number of Handlers: %ld", nbHandler);
            FCResponseStream* responseStream = [[FCResponseStream alloc] initWithRequest:request];
            NSMutableDictionary* context = [NSMutableDictionary new];
            for (int index = 0; index < nbHandler; index++)
            {
                FCHandlerItem* handlerItem = [handlers objectAtIndex:index];
                if ([handlerItem respondsToRequest:request])
                {
                    if (NO == [handlerItem handleRequest:request response:responseStream context:context])
                        break;
                }
            }
            context = nil;
            responseStream = nil;
            handlers = nil;
        }
    });
}


@end
