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
//  FCServerContext.m
//  Backtoweb
//


#import "FCServerContext.h"

//TODO remove WEB_ROOT from apache config

static NSString* getRootDir()
{
    NSString* path = [[[NSProcessInfo processInfo]environment]objectForKey:@"WEB_ROOT"];
    if (path == nil)
    {
        path = [[[NSProcessInfo processInfo]arguments] objectAtIndex:0];
        //vhosts/private/<hostname>/cgi-bin/fastcgiapp.fcgi
        path = [[path pathComponents] objectAtIndex:3];
        path = [NSString pathWithComponents:@[@"/vhosts/web/", path]];
    }
    return path;
}


static NSString* const kHandlersDir   = @"handlers";
static NSString* const kDataDir       = @"data";
static NSString* const kWebDir        = @"www";//or Documents
static NSString* const kLogsDir        = @"logs";
//static NSString* const kFrameworksDir = @"frameworks";



//On a OSX 10.8 dev machine, with default apache settings, user _www is used and its home directory is /Library/WebServer
//On depsys shard hosting, it should be chrooted to /<hostname>

@implementation FCServerContext
+ (FCServerContext*)sharedInstance
{
    static FCServerContext* sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sharedInstance = [[FCServerContext alloc] init]; });
    return sharedInstance;
}

- (NSString*)handlersDirectory
{
    NSString *serverRoot = getRootDir();
    return [serverRoot stringByAppendingPathComponent:kHandlersDir];
}

- (NSString*)dataDirectory
{
    NSString *serverRoot = getRootDir();
    return [serverRoot stringByAppendingPathComponent:kDataDir];
}

- (NSString*)webDirectory
{
    NSString *serverRoot = getRootDir();
    return [serverRoot stringByAppendingPathComponent:kWebDir];
}

- (NSString*)logsDirectory
{
    NSString *serverRoot = getRootDir();
    return [serverRoot stringByAppendingPathComponent:kLogsDir];
}

@end

