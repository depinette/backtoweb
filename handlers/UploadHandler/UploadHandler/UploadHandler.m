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
//  UploadHandler.m
//  UploadHandler
//

#import "UploadHandler.h"
#import <Backtoweb/DDData.h>

@implementation UploadHandler
+(void)initializeHandlers:(FCHandlerManager*)handlerManager
{
    //Go to http://localhost/upload to test this one
    
    //Send an html file depending on the browser accepted language
    //To ease the deployment of this handler, the HTML is encapsulated in the resources of the bundle
    //But it could be serve as a static HTML file by apache if you put it in the /Library/WebServer/Documents folder.
    [handlerManager
        addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
        {
            //get accepted language from the HTTP headers
            NSString* acceptLang = [request valueForHTTPHeaderField:@"HTTP_ACCEPT_LANGUAGE"];
            if (acceptLang && acceptLang.length > 2)
            {
                //we should parse it according to RFC2616 specification, but hey... this is just a sample.
                NSString *localizationName = [acceptLang substringToIndex:2];

                NSString* path = [[NSBundle bundleForClass:self.class] pathForResource:@"uploadfile" ofType:@"html" inDirectory:nil forLocalization:localizationName];
                if (!path)
                    path = [[NSBundle bundleForClass:self.class] pathForResource:@"uploadfile" ofType:@"html"];
                [responseStream writeStringWithFormat:@"%@", path];
                [responseStream writeData:[NSData dataWithContentsOfFile:path]];
            }
            return NO;
        }
     forRegexPath:@"^/upload" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
    
    //Responds to the form submission from the html file served above
    [handlerManager addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
     {
         //override default header which is text/html
         [responseStream writeHeaders:@{@"Content-Type": @"text/html; charset=utf-8"}];
         
         //browse form fields
         [responseStream writeString:@"<div style='border:1px solid black;margin:10px;'>"];
         NSDictionary* fields = [request allFormFields];
         for (NSString* key in fields)
         {
             NSString* field = [fields valueForKey:key];
             [responseStream writeStringWithFormat:@"%@=%@<br/><il>", key, field];
             
             [responseStream writeString:@"</il>"];
         }
         NSData *data = [NSData dataWithContentsOfFile:[fields valueForKey:@"uploaded_file1"]];
         if (data)
         {
             NSString* contentTypeImg = [fields valueForKey:[@"uploaded_file1" stringByAppendingString:@"$Content-Type"]];
             [responseStream writeStringWithFormat:@"<il>part content:<br/><img src=\"data:%@;base64,%@\"><br/></il>", contentTypeImg, [data base64Encoded]];
         }
         [responseStream writeString:@"</div>"];
         return NO;
     }
     forRegexPath:@"^/file_upload_form" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
}
@end
