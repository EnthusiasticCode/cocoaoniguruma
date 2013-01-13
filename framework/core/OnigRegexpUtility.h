// CocoaOniguruma is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the new BSD license.

#import <Foundation/Foundation.h>

@class OnigRegexp;
@class OnigResult;


@interface NSString (OnigRegexpUtility)

// pattern is OnigRegexp or NSString

- (NSRange)rangeOfRegexp:(id)pattern;

// based on ruby's split

- (NSArray*)split;
- (NSArray*)splitByRegexp:(id)pattern;
- (NSArray*)splitByRegexp:(id)pattern limit:(NSInteger)limit;

// based on ruby's gsub

- (instancetype)replaceByRegexp:(id)pattern with:(NSString*)string;
- (instancetype)replaceAllByRegexp:(id)pattern with:(NSString*)string;

- (instancetype)replaceByRegexp:(id)pattern withBlock:(NSString* (^)(OnigResult*))block;
- (instancetype)replaceAllByRegexp:(id)pattern withBlock:(NSString* (^)(OnigResult*))block;

@end
