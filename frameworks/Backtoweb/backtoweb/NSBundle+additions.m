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
//  NSBundle+additions.m
//  B2WHandler
//

//  Copyright (c) 2013 David EPINETTE. All rights reserved.
//

static int ddLogLevel = LOG_LEVEL_WARN;

#import "NSBundle+additions.h"
#import "FCHandlerItemPrivate.h"

@implementation NSBundle (additions)
+(NSBundle*)loadBundle:(NSString*)fullPath
{
    NSBundle *bundle = nil;
    bundle = [NSBundle bundleWithPath:fullPath];
    if (bundle)
    {
        NSError *error = nil;
        if ([bundle loadAndReturnError:&error])
        {
            DDLogVerbose(@"bundle %@ loaded", bundle);
        }
        else
        {
            DDLogError(@"Error %@ while loading bundle %@", error, fullPath);
        }
    }
    else
    {
        //check that the b2w file owner is appropriate
        DDLogError(@"Error while loading bundle %@", fullPath);
    }
    return bundle;
}

+(void)unloadBundle:(NSString*)fullPath
{
    NSArray* bundles = [NSBundle allBundles];
    if (bundles)
    {
        for (NSBundle* bundle in bundles)
        {
            if ([[bundle bundlePath] isEqualToString:fullPath])
                [bundle unload];
        }
    }
}

+(NSBundle*)bundleFromPath:(NSString*)fullPath
{
    NSArray* bundles = [NSBundle allBundles];
    if (bundles)
    {
        for (NSBundle* bundle in bundles)
        {
            if ([[bundle bundlePath] isEqualToString:fullPath])
            {
                return bundle;
            }
        }
    }
    return nil;
}

/*
-(Class)classFromBundlePath:(NSString*)fullPath
{
    NSArray* bundles = [NSBundle allBundles];
    if (bundles)
    {
        for (NSBundle* bundle in bundles)
        {
            if ([[bundle bundlePath] isEqualToString:fullPath])
            {
                if ([bundle isLoaded])
                    return [bundle principalClass];
            }
        }
    }
    return nil;
}
 */
@end
