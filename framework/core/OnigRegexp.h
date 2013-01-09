// CocoaOniguruma is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the new BSD license.

#import <Foundation/Foundation.h>
#import <CocoaOniguruma/OnigRegexpUtility.h>

@class OnigResult;


typedef enum {
    OnigOptionNone = 0U,
    OnigOptionIgnorecase = 1U,
    OnigOptionExtend = OnigOptionIgnorecase << 1,
    OnigOptionMultiline = OnigOptionExtend << 1,
    OnigOptionSingleline = OnigOptionMultiline << 1,
    OnigOptionFindLongest = OnigOptionSingleline << 1,
    OnigOptionFindNotEmpty = OnigOptionFindLongest << 1,
    OnigOptionNegateSingleLine = OnigOptionFindNotEmpty << 1,
    OnigOptionDontCaptureGroup = OnigOptionNegateSingleLine << 1,
    OnigOptionCaptureGroup = OnigOptionDontCaptureGroup << 1,
    
    /* options (search time) */
    OnigOptionNotbol = OnigOptionCaptureGroup << 1,
    OnigOptionNoteol = OnigOptionNotbol << 1,
    OnigOptionPosixRegion = OnigOptionNoteol << 1,
    OnigOptionMaxbit = OnigOptionPosixRegion,
} OnigOption;

@interface OnigRegexp : NSObject

+ (OnigRegexp*)compile:(NSString*)expression;
+ (OnigRegexp*)compile:(NSString*)expression error:(NSError **)error;
+ (OnigRegexp*)compileIgnorecase:(NSString*)expression;
+ (OnigRegexp*)compileIgnorecase:(NSString*)expression error:(NSError **)error;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline error:(NSError **)error;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended error:(NSError **)error;
+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)options;
+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)options error:(NSError **)error;

- (OnigResult*)search:(NSString*)target;
- (OnigResult*)search:(NSString*)target start:(NSUInteger)start;
- (OnigResult*)search:(NSString*)target start:(NSUInteger)start end:(NSInteger)end;
- (OnigResult*)search:(NSString*)target range:(NSRange)range;

- (OnigResult*)match:(NSString*)target;
- (OnigResult*)match:(NSString*)target start:(NSUInteger)start;

- (NSUInteger)captureCount;
- (NSString*)expression;

@end


@interface OnigResult : NSObject

- (NSString*)target;

- (NSUInteger)count;
- (NSString*)stringAt:(NSUInteger)index;
- (NSArray*)strings;
- (NSRange)rangeAt:(NSUInteger)index;
- (NSUInteger)locationAt:(NSUInteger)index;
- (NSUInteger)lengthAt:(NSUInteger)index;

- (NSString*)body;
- (NSRange)bodyRange;

- (NSString*)preMatch;
- (NSString*)postMatch;

// named capture support
- (NSArray*)captureNames;
- (NSInteger)indexForName:(NSString*)name;
- (NSIndexSet*)indexesForName:(NSString*)name;
- (NSString*)stringForName:(NSString*)name;
- (NSArray*)stringsForName:(NSString*)name;

@end
