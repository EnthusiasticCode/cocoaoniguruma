// CocoaOniguruma is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the new BSD license.

#import "OnigRegexp.h"
#import <objc/runtime.h>


#define CHAR_SIZE 2

#ifndef NSUTF16LittleEndianStringEncoding
#define NSUTF16LittleEndianStringEncoding (-1811939072)
#endif

#define STRING_ENCODING NSUTF16LittleEndianStringEncoding
#define ONIG_ENCODING ONIG_ENCODING_UTF16_LE

static OnigRegexp *_numberedCapturesRegexp;
static OnigRegexp *_escapedDollarSignsRegexp;
static OnigRegexp *_escapedNewlinesRegexp;
static OnigRegexp *_escapedTabsRegexp;
static OnigRegexp *_caseFoldingRegexp;

typedef enum
{
    _caseFoldingLockNone = 'E',
    _caseFoldingLockUpper = 'U',
    _caseFoldingLockLower = 'L',
} _caseFoldingLock;

typedef enum
{
    _caseFoldingNextNone = 0,
    _caseFoldingNextUpper = 'u',
    _caseFoldingNextLower = 'l',
} _caseFoldingNext;

@interface OnigResult (Private)
- (id)initWithRegexp:(OnigRegexp*)expression region:(OnigRegion*)region target:(NSString*)target;

- (NSMutableArray*) captureNameArray;

int co_name_callback(const OnigUChar* name, const OnigUChar* end, int ngroups, int* group_list, OnigRegex re, void* arg);

@end


@implementation OnigRegexp

+ (void)initialize
{
    if (self != [OnigRegexp class])
        return;
    _numberedCapturesRegexp = [OnigRegexp compile:@"\\$([0-9])" options:OnigOptionCaptureGroup];
    _escapedDollarSignsRegexp = [OnigRegexp compile:@"\\$"];
    _escapedNewlinesRegexp = [OnigRegexp compile:@"\\\\n"];
    _escapedTabsRegexp = [OnigRegexp compile:@"\\\\t"];
    _caseFoldingRegexp = [OnigRegexp compile:@"\\\\([ULEul])" options:OnigOptionCaptureGroup];
    ASSERT(_numberedCapturesRegexp && _escapedDollarSignsRegexp && _escapedNewlinesRegexp && _escapedTabsRegexp && _caseFoldingRegexp);
}

- (id)initWithEntity:(regex_t*)entity expression:(NSString*)expression
{
    self = [super init];
    if (self) {
        _entity = entity;
        _expression = [expression copy];
    }
    return self;
}

- (void)dealloc
{
    if (_entity) onig_free(_entity);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSUInteger)hash
{
    return [_expression hash];
}

+ (OnigRegexp*)compile:(NSString*)expression
{
    return [self compile:expression ignorecase:NO multiline:NO extended:NO error:NULL];
}

+ (OnigRegexp*)compile:(NSString*)expression error:(NSError **)error
{
    return [self compile:expression ignorecase:NO multiline:NO extended:NO error:error];
}

+ (OnigRegexp*)compileIgnorecase:(NSString*)expression
{
    return [self compile:expression ignorecase:YES multiline:NO extended:NO error:NULL];
}

+ (OnigRegexp*)compileIgnorecase:(NSString*)expression error:(NSError **)error
{
    return [self compile:expression ignorecase:YES multiline:NO extended:NO error:error];
}

+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline
{
    return [self compile:expression ignorecase:ignorecase multiline:multiline extended:NO error:NULL];
}

+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline error:(NSError **)error
{
    return [self compile:expression ignorecase:ignorecase multiline:multiline extended:NO error:NULL];
}

+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended
{
    return [self compile:expression ignorecase:ignorecase multiline:multiline extended:extended error:NULL];
}

+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended error:(NSError **)error
{
    OnigOption options = OnigOptionNone;
    options |= multiline ? OnigOptionMultiline : OnigOptionSingleline;
    if(ignorecase) options |= OnigOptionIgnorecase;
    if(extended) options |= OnigOptionExtend;
    return [self compile:expression options:options error:error];
}

+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)theOptions
{
    return [self compile:expression options:theOptions error:NULL];
}

+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)theOptions error:(NSError **)error
{
    if (!expression) {
        if(error != NULL) {
            //Make NSError;
            NSDictionary* dict = [NSDictionary dictionaryWithObject:@"Invalid expression argument"
                                                             forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"CocoaOniguruma" code:ONIG_NORMAL userInfo:dict];
        }
        return nil;
    }
    
    OnigOptionType option = theOptions;
    
    OnigErrorInfo err;
    regex_t* entity = 0;
    const UChar* str = (const UChar*)[expression cStringUsingEncoding:STRING_ENCODING];
    
    int status = onig_new(&entity,
                          str,
                          str + [expression length] * CHAR_SIZE,
                          option,
                          ONIG_ENCODING,
                          ONIG_SYNTAX_DEFAULT,
                          &err);
    
    if (status == ONIG_NORMAL) {
        return [[self alloc] initWithEntity:entity expression:expression];
    }
    else {
        if(error != NULL) {
            //Make NSError;
            UChar str[ONIG_MAX_ERROR_MESSAGE_LEN];
            onig_error_code_to_str(str, status, &err);
            NSString* errorStr = [NSString stringWithCString:(char*)str
                                                    encoding:NSASCIIStringEncoding];
            NSDictionary* dict = [NSDictionary dictionaryWithObject:errorStr
                                                             forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"CocoaOniguruma" code:status userInfo:dict];
        }
        if (entity) onig_free(entity);
        return nil;
    }
}

- (OnigResult*)search:(NSString*)target
{
    return [self search:target start:0 end:-1];
}

- (OnigResult*)search:(NSString*)target start:(int)start
{
    return [self search:target start:start end:-1];
}

- (OnigResult*)search:(NSString*)target start:(int)start end:(int)end
{
    if (!target) return nil;
    if (end < 0) end = [target length];
    
    OnigRegion* region = onig_region_new();

    const UChar* str = (const UChar*)[target cStringUsingEncoding:STRING_ENCODING];
    
    int status = onig_search(_entity,
                             str,
                             str + [target length] * CHAR_SIZE,
                             str + start * CHAR_SIZE,
                             str + end * CHAR_SIZE,
                             region,
                             ONIG_OPTION_NONE);
    
    if (status != ONIG_MISMATCH) {
        return [[OnigResult alloc] initWithRegexp:self region:region target:target];
    }
    else {
        onig_region_free(region, 1);
        return nil;
    }
}

- (OnigResult*)search:(NSString*)target range:(NSRange)range
{
    return [self search:target start:range.location end:NSMaxRange(range)];
}

- (OnigResult*)match:(NSString*)target
{
    return [self match:target start:0];
}

- (OnigResult*)match:(NSString*)target start:(int)start
{
    if (!target) return nil;
    
    OnigRegion* region = onig_region_new();

    const UChar* str = (const UChar*)[target cStringUsingEncoding:STRING_ENCODING];
    
    int status = onig_match(_entity,
                            str,
                            str + [target length] * CHAR_SIZE,
                            str + start * CHAR_SIZE,
                            region,
                            ONIG_OPTION_NONE);
    
    if (status != ONIG_MISMATCH) {
        return [[OnigResult alloc] initWithRegexp:self region:region target:target];
    }
    else {
        onig_region_free(region, 1);
        return nil;
    }
}

- (void)gsub:(NSMutableString *)target block:(NSString *(^)(OnigResult *, BOOL *))block
{
    [self gsub:target block:block range:NSMakeRange(0, [target length])];
}

- (void)gsub:(NSMutableString *)target block:(NSString *(^)(OnigResult *, BOOL *))block range:(NSRange)range
{
    NSUInteger start = range.location;
    NSUInteger end = NSMaxRange(range);
    OnigResult *result = [self search:target start:start end:end];
    NSRange resultRange = [result bodyRange];
    start = resultRange.location;
    BOOL stop = NO;
    while (result)
    {
        NSString *replacement = block(result, &stop);
        if ([replacement length])
        {
            start += [replacement length];
            end += [replacement length];
            if (resultRange.length)
            {
                [target replaceCharactersInRange:resultRange withString:replacement];
                end -= resultRange.length;
            }
            else
            {
                [target insertString:replacement atIndex:resultRange.location];
            }
        }
        else
        {
            if (resultRange.length)
            {
                [target deleteCharactersInRange:resultRange];
                end -= resultRange.length;
            }
            else
            {
                // force advancement of start to avoid infinite loops when the regexp matches zero width and the replacement is nil
                ++start;
            }
        }
        if (stop)
            return;
        result = [self search:target start:start end:end];
        resultRange = [result bodyRange];
        start = resultRange.location;
    }
}

- (void)sub:(NSMutableString *)target string:(NSString *)string
{
    [self sub:target string:string range:NSMakeRange(0, [target length])];
}

- (void)sub:(NSMutableString *)target string:(NSString *)string range:(NSRange)range
{
    [self gsub:target block:^NSString *(OnigResult *result, BOOL *stop) {
        *stop = YES;
        return [result stringForReplacementTemplate:string];
    } range:range];
}

- (void)gsub:(NSMutableString *)target string:(NSString *)string
{
    [self gsub:target string:string range:NSMakeRange(0, [target length])];
}

- (void)gsub:(NSMutableString *)target string:(NSString *)string range:(NSRange)range
{
    [self gsub:target block:^NSString *(OnigResult *result, BOOL *stop) {
        return [result stringForReplacementTemplate:string];
    } range:range];
}

- (NSString*)expression
{
    return _expression;
}

- (regex_t*)entity
{
    return _entity;
}

@end


@implementation OnigResult

- (id)initWithRegexp:(OnigRegexp*)expression region:(OnigRegion*)region target:(NSString*)target
{
    self = [super init];
    if (self) {
        _expression = expression;
        _region = region;
        _target = [target copy];
        _captureNames = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    if (_region) onig_region_free(_region, 1);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSUInteger)hash
{
    return [_expression hash];
}

- (NSString*)target
{
    return _target;
}

- (int)size
{
    return [self count];
}

- (int)count
{
    return _region->num_regs;
}

- (NSString*)stringAt:(int)index
{
    return [_target substringWithRange:[self rangeAt:index]];
}

- (NSArray*)strings
{
    NSMutableArray* array = [NSMutableArray array];
    int i, count;
    for (i=0, count=[self count]; i<count; i++) {
        [array addObject:[self stringAt:i]];
    }
    return array;
}

- (NSRange)rangeAt:(int)index
{
    return NSMakeRange([self locationAt:index], [self lengthAt:index]);
}

- (int)locationAt:(int)index
{
    return *(_region->beg + index) / CHAR_SIZE;
}

- (int)lengthAt:(int)index
{
    return (*(_region->end + index) - *(_region->beg + index)) / CHAR_SIZE;
}

- (NSString*)body
{
    return [self stringAt:0];
}

- (NSRange)bodyRange
{
    return [self rangeAt:0];
}

- (NSString*)preMatch
{
    return [_target substringToIndex:[self locationAt:0]];
}

- (NSString*)postMatch
{
    return [_target substringFromIndex:[self locationAt:0] + [self lengthAt:0]];
}

- (NSMutableArray*) captureNameArray {
    return self->_captureNames;
}

// Used to get list of names
int co_name_callback(const OnigUChar* name, const OnigUChar* end, int ngroups, int* group_list, OnigRegex re, void* arg) {
    OnigResult *result = (__bridge OnigResult *)arg;
    
    [[result captureNameArray] addObject:[NSString stringWithCharacters:(unichar*)name length:((end-name)/CHAR_SIZE)]];
    return 0;
}

- (NSArray*)captureNames
{
    onig_foreach_name([self->_expression entity], co_name_callback, (__bridge void*)self);
    return [NSArray arrayWithArray:self->_captureNames];
}

- (int)indexForName:(NSString*)name
{
    NSIndexSet* indexes = [self indexesForName:name];
    return indexes ? [indexes firstIndex] : -1;
}

- (NSIndexSet*)indexesForName:(NSString*)name
{
    int* buf = NULL;
    const UChar* str = (const UChar*)[name cStringUsingEncoding:STRING_ENCODING];
    
    int num = onig_name_to_group_numbers([_expression entity], str, str + [name length] * CHAR_SIZE, &buf);
    if (num < 0) return nil;
    
    NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
    int i;
    for (i=0; i<num; i++) {
        [indexes addIndex:buf[i]];
    }
    return indexes;
}

- (NSString*)stringForName:(NSString*)name
{
    int n = [self indexForName:name];
    return n < 0 ? nil : [self stringAt:n];
}

- (NSArray*)stringsForName:(NSString*)name
{
    NSIndexSet* indexes = [self indexesForName:name];
    if (!indexes) return nil;
    
    NSMutableArray* array = [NSMutableArray array];
    NSUInteger i;
    for (i=[indexes firstIndex]; i!=NSNotFound; i=[indexes indexGreaterThanIndex:i]) {
        [array addObject:[self stringAt:i]];
    }
    return array;
}

- (NSString *)stringForReplacementTemplate:(NSString *)replacementTemplate
{
    NSMutableString *replacement = [replacementTemplate mutableCopy];
    [_numberedCapturesRegexp gsub:replacement block:^NSString *(OnigResult *result, BOOL *stop) {
        int captureNumber = [[result stringAt:1] intValue];
        if (captureNumber >= 0 && [self count] > captureNumber)
            return [self stringAt:captureNumber];
        else
            return nil;
    }];
    [_escapedDollarSignsRegexp gsub:replacement block:^NSString *(OnigResult *result, BOOL *stop) {
        return @"$";
    }];
    [_escapedNewlinesRegexp gsub:replacement block:^NSString *(OnigResult *result, BOOL *stop) {
        return @"\n";
    }];
    [_escapedTabsRegexp gsub:replacement block:^NSString *(OnigResult *result, BOOL *stop) {
        return @"\t";
    }];
    
    __block _caseFoldingLock caseFoldingLock = _caseFoldingLockNone;
    __block _caseFoldingNext caseFoldingNext = _caseFoldingNextNone;
    __block NSUInteger pendingCaseFoldingLockStart = 0;
    __block NSUInteger pendingCaseFoldingNextOffset = 0;
    
    [_caseFoldingRegexp gsub:replacement block:^NSString *(OnigResult *result, BOOL *stop) {
        char caseFoldingIdentifierChar = *[[result stringAt:1] UTF8String];
        if (caseFoldingIdentifierChar == _caseFoldingLockNone || caseFoldingIdentifierChar == _caseFoldingLockUpper || caseFoldingIdentifierChar == _caseFoldingLockLower)
        {
            // The case folding modifier is already active, do nothing
            if (caseFoldingIdentifierChar == caseFoldingLock)
                return nil;
            // The previous case folding lock modifier was none, do nothing
            if (caseFoldingLock == _caseFoldingLockNone)
            {
                caseFoldingLock = caseFoldingIdentifierChar;
                pendingCaseFoldingLockStart = [result bodyRange].location;
                return nil;
            }
            NSRange pendingRange = NSMakeRange(pendingCaseFoldingLockStart, [result bodyRange].location - pendingCaseFoldingLockStart);
            NSString *pendingString = [replacement substringWithRange:pendingRange];
            if (caseFoldingLock == _caseFoldingLockUpper)
                pendingString = [pendingString uppercaseString];
            else
                pendingString = [pendingString lowercaseString];
            [replacement replaceCharactersInRange:pendingRange withString:pendingString];
            caseFoldingLock = caseFoldingIdentifierChar;
        }
        else
        {
            // The case folding modifier is already active, do nothing
            if (caseFoldingIdentifierChar == caseFoldingNext)
                return nil;
            // The previous case folding next modifier was none, do nothing
            if (caseFoldingNext == _caseFoldingNextNone)
            {
                caseFoldingNext = caseFoldingIdentifierChar;
                pendingCaseFoldingNextOffset = [result bodyRange].location;
                return nil;
            }
            // Apply the pending case folding modifier
            // Because the next type modifiers override the lock type modifiers, we need to apply the latter before the first
            if (caseFoldingLock != _caseFoldingLockNone)
            {
                NSRange pendingRange = NSMakeRange(pendingCaseFoldingLockStart, [result bodyRange].location - pendingCaseFoldingLockStart);
                NSString *pendingString = [replacement substringWithRange:pendingRange];
                if (caseFoldingLock == _caseFoldingLockUpper)
                    pendingString = [pendingString uppercaseString];
                else
                    pendingString = [pendingString lowercaseString];
                [replacement replaceCharactersInRange:pendingRange withString:pendingString];
                pendingCaseFoldingLockStart = [result bodyRange].location;
            }
            NSRange pendingRange = NSMakeRange(pendingCaseFoldingNextOffset, 1);
            NSString *pendingCharacter = [replacement substringWithRange:pendingRange];
            if (caseFoldingNext == _caseFoldingNextUpper)
                pendingCharacter = [pendingCharacter uppercaseString];
            else
                pendingCharacter = [pendingCharacter lowercaseString];
            [replacement replaceCharactersInRange:pendingRange withString:pendingCharacter];
            caseFoldingNext = caseFoldingIdentifierChar;
        }
        return nil;
    }];
    // Take care of any pending modifiers
    if (caseFoldingLock != _caseFoldingLockNone)
    {
        NSRange pendingRange = NSMakeRange(pendingCaseFoldingLockStart, [replacement length] - pendingCaseFoldingLockStart);
        NSString *pendingString = [replacement substringWithRange:pendingRange];
        if (caseFoldingLock == _caseFoldingLockUpper)
            pendingString = [pendingString uppercaseString];
        else
            pendingString = [pendingString lowercaseString];
        [replacement replaceCharactersInRange:pendingRange withString:pendingString];
    }
    if (caseFoldingNext != _caseFoldingNextNone && pendingCaseFoldingNextOffset != [replacement length])
    {
        NSRange pendingRange = NSMakeRange(pendingCaseFoldingNextOffset, 1);
        NSString *pendingCharacter = [replacement substringWithRange:pendingRange];
        if (caseFoldingNext == _caseFoldingNextUpper)
            pendingCharacter = [pendingCharacter uppercaseString];
        else
            pendingCharacter = [pendingCharacter lowercaseString];
        [replacement replaceCharactersInRange:pendingRange withString:pendingCharacter];
    }
    return [replacement copy];
}

@end
