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
//  AppDelegate.m
//  CopyHelper
//


#import "AppDelegate.h"

NSString* launchTask(NSArray* args)
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: [args objectAtIndex:0]];
    
    [task setArguments: [args subarrayWithRange:NSMakeRange(1, args.count - 1)]];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardError: pipe];//test
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    //BOOL exists = [[NSFileManager defaultManager] isExecutableFileAtPath:[task launchPath]];
    [task launch];
    [task waitUntilExit];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[NSString alloc] initWithData: data
                                   encoding: NSUTF8StringEncoding];
    return string;
}

@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    // ...
    
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:)
                                                     forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSAppleEventDescriptor *addrDesc = nil;
    addrDesc = [event attributeDescriptorForKeyword:keySenderPIDAttr];
    SInt32 pid = [[addrDesc coerceToDescriptorType:typeSInt32] int32Value];
    
    //[self.textView insertNewline:nil];
    //[self.textView insertText:[NSString stringWithFormat:@"pid %d", pid]];
    
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL* url = [NSURL URLWithString:urlString];
    
    [self trace:[NSString stringWithFormat:@"received %@", urlString]];

    
    //addrDesc = [event    attributeDescriptorForKeyword:keyOriginalAddressAttr];//rkeyAddressAttr];
    //NSData *psnData = [[addrDesc   coerceToDescriptorType:typeProcessSerialNumber] data];
    //ProcessSerialNumber psn = *(ProcessSerialNumber *) [psnData bytes];
    ProcessSerialNumber psn;
    OSStatus err = GetProcessForPID(pid, &psn);
    if (err == noErr)
    {
        NSDictionary* dico = (__bridge_transfer NSDictionary*)ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
        
        NSString *bundleName = [dico valueForKey:@"CFBundleName"];
        if ([bundleName isEqualToString:@"open"])
        {
    //        NSNumber* psnParent = [dico valueForKey:@"ParentPSN"];
    //        long long ll = [psnParent longLongValue];
    //        psn.lowLongOfPSN = ll&0xFFFFFFFF;
    //        psn.highLongOfPSN = ll>>32;
    //        dico = (__bridge_transfer  NSDictionary*)ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
    //        NSString* bundlePath = [dico valueForKey:@"BundlePath"];
    //        if ([bundlePath hasSuffix:@"Xcode.app"])
            {
                NSError *error = nil;
                
                //restart apache
                if ([url.host isEqualToString:@"restartapache"])
                {
                    launchTask(@[@"/usr/bin/sudo", @"/usr/sbin/apachectl", @"restart"]);
                }
                //copy 1 file
                else if ([url.host isEqualToString:@"copyfile"])
                {
                    NSFileManager* fileManager = [NSFileManager new];
                    if (fileManager && [fileManager fileExistsAtPath:url.path])
                    {
                        NSArray* params = [url.query componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"&="]];
                        if (params.count >1)
                        {
                            NSString *source = [url.path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                            NSString *destination = [[params objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                            if ([fileManager fileExistsAtPath:destination])
                                [fileManager removeItemAtPath:destination error:&error];
                            else
                                [fileManager createDirectoryAtPath:[destination stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
                            if (!error && YES == [fileManager copyItemAtPath:source toPath:destination error:&error])
                            {
                                [self.textView insertNewline:nil];
                                [self.textView insertText:[NSString stringWithFormat:@"Successfully copied %@ to %@", source, destination]];
                            }
                        }
                    }
                }
                //copy files
                else if ([url.host isEqualToString:@"copyfiles"])
                {
                    NSFileManager* fileManager = [NSFileManager new];
                    BOOL isDirectory = NO;
                    [self trace:url.path];
                    if (fileManager && [fileManager fileExistsAtPath:url.path isDirectory:&isDirectory] && isDirectory == YES)
                    {
                        NSString* destinationDir = nil, *extension = nil;
                        NSArray* params = [url.query componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"&="]];
                        if ((params.count%2)==0)//is pair?
                        {
                            for (int i = 0; i < params.count; i++)
                            {
                                NSString* param = [params objectAtIndex:i];
                                if ([param isEqualToString:@"to"])
                                {
                                    i++;
                                    destinationDir = [[params objectAtIndex:i] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                }
                                if ([param isEqualToString:@"extension"])
                                {
                                    i++;
                                    extension = [[params objectAtIndex:i] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                }
                                
                            }
                        }

                        if (destinationDir)
                        {
                            NSString *sourceDir = [url.path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//[self trace:[NSString stringWithFormat:@"%@ %@", sourceDir, destinationDir]];
                            [fileManager createDirectoryAtPath:destinationDir withIntermediateDirectories:YES attributes:nil error:&error];
                            
                            NSArray *contents = [fileManager contentsOfDirectoryAtPath:sourceDir error:&error];
                            for (NSString* item in contents)
                            {
                                if (error)
                                    break;
                                NSString *destinationFile = [destinationDir stringByAppendingPathComponent:item];
                                if ([[item pathExtension] isEqualToString:extension])
                                {
//[self trace:[NSString stringWithFormat:@"item:%@ %@", [sourceDir stringByAppendingPathComponent:item], destinationFile]];
                                    if ([fileManager fileExistsAtPath:destinationFile])
                                        [fileManager removeItemAtPath:destinationFile error:&error];
                                    if (YES == [fileManager copyItemAtPath:[sourceDir stringByAppendingPathComponent:item] toPath:destinationFile error:&error])
                                    {
                                        [self.textView insertNewline:nil];
                                        [self.textView insertText:[NSString stringWithFormat:@"Successfully copied %@ to %@", [sourceDir stringByAppendingPathComponent:item], destinationFile]];
                                    }
                                }
                            }
                        }
                        
                    }
                    
                }
                
                if (error)
                {
                    [self.textView insertNewline:nil];
                    [self.textView insertText:error.description];
                }
            }
        }
    }
}

-(void)trace:(NSString*)text
{
    [self.textView insertNewline:nil];
    [self.textView insertText:text];
    
}

@end
