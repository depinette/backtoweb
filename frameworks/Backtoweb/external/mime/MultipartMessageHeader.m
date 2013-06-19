//
//  MultipartMessagePart.m
//  HttpServer
//
//  Created by Валерий Гаврилов on 29.03.12.
//  Copyright (c) 2012 LLC "Online Publishing Partners" (onlinepp.ru). All rights reserved.

#import "MultipartMessageHeader.h"
#import "MultipartMessageHeaderField.h"


//-----------------------------------------------------------------
#pragma mark log level
/*
#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_WARN;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
*/
//-----------------------------------------------------------------
// implementation MultipartMessageHeader
//-----------------------------------------------------------------


@implementation MultipartMessageHeader
@synthesize fields,encoding;


- (id) initWithData:(NSData *)data formEncoding:(NSStringEncoding) formEncoding {
	if( nil == (self = [super init]) ) {
        return self;
    }
	
	fields = [[NSMutableDictionary alloc] initWithCapacity:1];

	// In case encoding is not mentioned,
	encoding = contentTransferEncoding_unknown;

	char* bytes = (char*)data.bytes;
	int length = data.length;
	int offset = 0;

	// split header into header fields, separated by \r\n
	uint16_t fields_separator = 0x0A0D; // \r\n
	while( offset < length - 2 ) {

		// the !isspace condition is to support header unfolding (removing CRLF followed immediately by WSP)
		if( (*(uint16_t*) (bytes+offset)  == fields_separator) &&
           //((offset == length - 2) || !(isspace(bytes[offset+2]))) //pb with isspace is that \r is considered as a space WSP seems to be either a space or HTAB
           ((offset == length - 2) || (bytes[offset+2] != ' ' && bytes[offset+2] != '\t'))
        )
        {
			NSData* fieldData = [NSData dataWithBytesNoCopy:bytes length:offset freeWhenDone:NO];
			MultipartMessageHeaderField* field = [[MultipartMessageHeaderField alloc] initWithData: fieldData  contentEncoding:formEncoding];
			if( field ) {
				[fields setObject:field forKey:field.name];
				DDLogVerbose(@"MultipartFormDataParser: Processed Header field '%@'",field.name);
			}
			else {
				NSString* fieldStr = [[NSString  alloc] initWithData:fieldData encoding:NSASCIIStringEncoding];
				DDLogWarn(@"MultipartFormDataParser: Failed to parse MIME header field. Input ASCII string:%@",fieldStr);
			}

			// move to the next header field
			bytes += offset + 2;
			length -= offset + 2;
			offset = 0;
			continue;
		}
		++ offset;
	}
	
	if( !fields.count ) {
		// it was an empty header.
		// we have to set default values.
		// default header.
		[fields setObject:@"text/plain" forKey:@"Content-Type"];
	}

	return self;
}

- (NSString *)description {	
	return [NSString stringWithFormat:@"%@",fields];
}


@end
