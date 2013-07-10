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
//  ImageHandler.m
//  SamplesHandler
//


#import "ImageHandler.h"


@implementation ImageHandler
+(void)initializeHandlers:(FCHandlerManager*)handlerManager
{
    ddLogLevel = LOG_LEVEL_ERROR;
    [handlerManager addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
     {
         DDLogVerbose(@"Image sample handler called");
         
         //set content type, must be sent before anything else.
         [responseStream writeValue:@"image/png" forHeader:@"Content-type"];
         
         
         NSRect bounds = NSMakeRect(0.0, 0.0, 200.0, 400.0);
         NSImage* anImage = [[NSImage alloc] initWithSize:NSMakeSize(bounds.size.width, bounds.size.height)];
         [anImage lockFocus];
         
         //draw a gradient in a round rect path
         NSBezierPath* path = [NSBezierPath bezierPath];
         [path appendBezierPathWithRoundedRect:bounds xRadius:4*bounds.size.width/100 yRadius:3*bounds.size.width/100];
         
         
         NSGradient* aGradient = [[NSGradient alloc]
                                  initWithColorsAndLocations:
                                  [NSColor redColor], 0.0f,
                                  [NSColor orangeColor], 0.166f,
                                  [NSColor yellowColor], 0.33f,
                                  [NSColor greenColor], 0.5f,
                                  [NSColor blueColor], 0.75f,
                                  [NSColor purpleColor], 1.0f,
                                  nil] ;
         [aGradient drawInBezierPath:path angle:90.0];
         
         NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, anImage.size.width, anImage.size.height)];
         [anImage unlockFocus];
         
         [responseStream writeData:[bitmapRep representationUsingType:NSPNGFileType properties:nil]];
         
         return NO;
     }
     forLiteralPath:@"/samples/img" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
}
@end
