//
//  EmojiHandler.m
//  SamplesHandler
//
//  Created by depsys on 15/07/13.
//  Copyright (c) 2013 depsys. All rights reserved.
//

#import "EmojiHandler.h"


@implementation EmojiHandler
+(void)initializeHandlers:(FCHandlerManager*)handlerManager
{
    //render unicode char using Emoji font
    //for example http://<hostname>/emoji?code=1F419&size=120
    [handlerManager addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
     {
         //get form imput values//////////////
         NSDictionary* values = [request allFormFields];
         NSString* universalCode = [values valueForKey:@"code"];//universal code
         NSString* sizeAsString = [values valueForKey:@"size"];         
         if (!universalCode) universalCode = @"1F419";
         
         //transform input//////////////
         NSScanner* scanner = [NSScanner scannerWithString:universalCode];
         if (scanner)
         {
             unsigned int code;
             [scanner scanHexInt:&code];
             if (code > 0XFFFF)// check max UTF16
             {
                 UTF32Char inputChar = code;// my UTF-32 character
                 inputChar -= 0x10000;
                 unichar highSurrogate = inputChar >> 10; // leave the top 10 bits
                 highSurrogate += 0xD800;
                 unichar lowSurrogate = inputChar & 0x3FF; // leave the low 10 bits
                 lowSurrogate += 0xDC00;
                 universalCode = [NSString stringWithCharacters:(unichar[]){highSurrogate, lowSurrogate} length:2];
             }
             else
             {
                 universalCode = [NSString stringWithCharacters:(const unichar*)&code length:1];
             }
         }
         
         CGFloat size = sizeAsString?[sizeAsString floatValue]:120.0f;
         NSFont *font = [[NSFontManager sharedFontManager] fontWithFamily:@"Apple Color Emoji"
                                                                   traits:0
                                                                   weight:5
                                                                     size:size];
         
         //Draw the character//////////////
         // Create the attributed string
         NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
         NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:universalCode attributes:stringAttributes];
         
         NSBitmapImageRep *bitmapRep = nil;
         CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attrString);
         if (line)
         {
             CFIndex glyphCount = CTLineGetGlyphCount(line);
             if (glyphCount > 0)
             {
                 CGRect rectLine = CTLineGetBoundsWithOptions(line, kCTLineBoundsUseGlyphPathBounds|kCTLineBoundsExcludeTypographicLeading);
                 CGSize sizeImg = NSMakeSize(rectLine.size.width, rectLine.size.height);
                 
                 bitmapRep = [[NSBitmapImageRep alloc]
                              initWithBitmapDataPlanes:NULL
                              pixelsWide:sizeImg.width
                              pixelsHigh:sizeImg.height
                              bitsPerSample:8
                              samplesPerPixel:4
                              hasAlpha:YES
                              isPlanar:NO
                              colorSpaceName:NSCalibratedRGBColorSpace
                              bytesPerRow:0
                              bitsPerPixel:0];
                 [bitmapRep setSize:sizeImg];
                 [NSGraphicsContext saveGraphicsState];
                 NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapRep];
                 [NSGraphicsContext setCurrentContext:graphicsContext];
                 CGContextRef context = (CGContextRef)(graphicsContext.graphicsPort);
                 
                 if (context)
                 {
                     CGContextSetTextMatrix(context, CGAffineTransformIdentity);
                     CGContextSetTextPosition(context, -rectLine.origin.x, -rectLine.origin.y);//rect.origin is relative to the start point of the baseline.
                     CTLineDraw(line, context);
                 }
                 
                 //send back the image
                 if (bitmapRep)
                 {
                     [responseStream writeValue:@"image/png" forHeader:@"Content-type"];
                     NSData *data = [bitmapRep representationUsingType:NSPNGFileType properties:nil];
                     [responseStream writeData:data];
                 }
                 [NSGraphicsContext restoreGraphicsState];
             }
             CFRelease(line);
         }
         if (bitmapRep == nil)
             [responseStream writeValue:@"500" forHeader:@"Status"];
         return NO;
         
     } forLiteralPath:@"/samples/emoji" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
    
}
@end


