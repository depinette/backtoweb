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
//  main.m
//  fastcgitest

#import <Foundation/Foundation.h>
#import <Lumberjack/DDASLLogger.h>
#import <Lumberjack/DDTTYLogger.h>
#import <Lumberjack/DDFileLogger.h>
#import <backtoweb/backtoweb.h>
#import <backtoweb/FCURLRequestPrivate.h>
#import <backtoweb/FCHandlerManagerPrivate.h>

//NSLog goes in apache error log: file://private/var/log/apache2/error_log

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        //setup logs
        //[DDLog addLogger:[DDASLLogger sharedInstance]];//Console
        //[DDLog addLogger:[DDTTYLogger sharedInstance]];//NSLog
        DDLogFileManagerDefault *fileManager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:[[FCServerContext sharedInstance] logsDirectory]];
        __strong DDFileLogger *fileLogger = [[DDFileLogger alloc] initWithLogFileManager:fileManager];
        [fileLogger setMaximumFileSize:(1024 * 1024)];
        [fileLogger setRollingFrequency:(3600.0 * 24.0)];
        [[fileLogger logFileManager] setMaximumNumberOfLogFiles:7];
        [DDLog addLogger:fileLogger];

        
#ifdef DEBUG
        ddLogLevel = LOG_LEVEL_VERBOSE;
#else
        ddLogLevel = ddDefaultLogLevel;
#endif
        /*
        NSString* path = [[NSString alloc] initWithCString:argv[0] encoding:NSUTF8StringEncoding];
        path = [[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
         */
        
        FCHandlerManager* handlerManager = [FCHandlerManager sharedInstance];

        NSString *path = [[FCServerContext sharedInstance] handlersDirectory];
        [handlerManager loadHandlerBundles:path];
        [handlerManager findAndRegisterHandlers];
        
        for (;;)
        {
            @autoreleasepool
            {
                
                FCURLRequest* request = [FCURLRequest waitForNextIncomingRequest];
                if (request)
                {
                    DDLogCVerbose(@"handling request %@", request.URL.absoluteString);
                    [handlerManager handleRequest:request];
                    //NSLog(@"end handling");
                    request = nil;
                }
                else
                {
                    //never called. TODO non blocking socket with SIGUSR1 handling?
                    //FCHandlerManager* handlerManager = [FCHandlerManager sharedInstance];
                    //[handlerManager willTerminate];
                    DDLogCError(@"request null");
                }
            }
        }
    }
    return 0;
}


