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
//  HelloWorldHandler.m
//  HelloWorldHandler
//


#import "HelloWorldHandler.h"

@implementation HelloWorldHandler
+(void)initializeHandlers:(FCHandlerManager*)handlerManager
{
    [handlerManager
        addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
        {
            [responseStream writeString:@"Hello world !"];

            return NO; //do not try to find another handler
        }
     forLiteralPath:@"/samples/hello/world" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
    
    [handlerManager
        addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
        {
            [responseStream writeString:@"Hello world !<br/>"];
            
            //print url
            [responseStream writeStringWithFormat:@"<h2>URL</h2>%@ <br/>", request.URL.absoluteString];
            
            //print all HTTP headers + variables available in the request
            NSDictionary* fields = [request allHTTPHeaderFields];
            [responseStream writeString:@"<h2>HTTP headers and fastCGI variables</h2>"];
            for (NSString* field in fields)
            {
                [responseStream writeStringWithFormat:@"%@ = %@<br/>", field, [fields valueForKey:field]];
            }
            
            //print all form fields
            [responseStream writeString:@"<h2>Form fields</h2>"];
            fields = [request allFormFields];
            if (fields.count == 0)
                [responseStream writeString:@"<p>No form field, try appending a query to the url (ie '?myvar=myvalue')</p>"];    
            for (NSString* field in fields)
            {
                [responseStream writeStringWithFormat:@"%@ = %@<br/>", field, [fields valueForKey:field]];

            }
                         
            return NO; //do not try to find another handler
        }
     forLiteralPath:@"/samples/hello/vars" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
}
@end

