//
//  YMTransferState.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMTransferState.h"

#define YM_DELIMITERS_CR 0x0d
#define YM_DELIMITERS_LR 0x0a

@implementation YMTransferState

- (instancetype)initWithURL:(NSURL *)url bodyDataDrain:(YMDataDrain *)bodyDataDrain {
    self = [super init];
    if (self) {
        _url = url;
        _parsedResponseHeader = [[YMParsedResponseHeader alloc] init];
        _response = nil;
        _requestBodySource = nil;
        _bodyDataDrain = bodyDataDrain;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
              bodyDataDrain:(YMDataDrain *)bodyDataDrain
                 bodySource:(id<YMURLSessionTaskBodySource>)bodySource {
    self = [super init];
    if (self) {
        _url = url;
        _parsedResponseHeader = [[YMParsedResponseHeader alloc] init];
        _response = nil;
        _requestBodySource = bodySource;
        _bodyDataDrain = bodyDataDrain;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
       parsedResponseHeader:(YMParsedResponseHeader *)parsedResponseHeader
                   response:(NSURLResponse *)response
                 bodySource:(id<YMURLSessionTaskBodySource>)bodySource
              bodyDataDrain:(YMDataDrain *)bodyDataDrain {
    self = [super init];
    if (self) {
        _url = url;
        _parsedResponseHeader = parsedResponseHeader;
        _response = response;
        _requestBodySource = bodySource;
        _bodyDataDrain = bodyDataDrain;
    }
    return self;
}

- (YMTransferState *)byAppendingHTTPHeaderLineData:(NSData *)data error:(NSError *__autoreleasing _Nullable *)error {
    YMParsedResponseHeader *h = [_parsedResponseHeader byAppendingHeaderLine:data];
    if (!h) {
        // TODO: Error
        *error = [NSError errorWithDomain:@"YMHTTPParseSingleLineError" code:-1 userInfo:nil];
        return nil;
    }

    if (h.type == YMParsedResponseHeaderTypeComplete) {
        NSHTTPURLResponse *response = [h createHTTPURLResponseForURL:_url];
        if (!response) {
            // TODO: Error
            *error = [NSError errorWithDomain:@"YMHTTPParseCompleteHeaderError" code:-1 userInfo:nil];
            return nil;
        }
        YMParsedResponseHeader *ph = [[YMParsedResponseHeader alloc] init];
        YMTransferState *ts = [[YMTransferState alloc] initWithURL:_url
                                              parsedResponseHeader:ph
                                                          response:response
                                                        bodySource:_requestBodySource
                                                     bodyDataDrain:_bodyDataDrain];
        return ts;
    } else {
        YMTransferState *ts = [[YMTransferState alloc] initWithURL:_url
                                              parsedResponseHeader:h
                                                          response:nil
                                                        bodySource:_requestBodySource
                                                     bodyDataDrain:_bodyDataDrain];
        return ts;
    }
}

@end

@implementation YMDataDrain

@end

@implementation YMParsedResponseHeader

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = YMParsedResponseHeaderTypePartial;
        _lines = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)byAppendingHeaderLine:(NSData *)data {
    NSUInteger length = data.length;
    if (length >= 2) {
        uint8_t last2;
        uint8_t last1;
        [data getBytes:&last2 range:NSMakeRange(length - 2, 1)];
        [data getBytes:&last1 range:NSMakeRange(length - 1, 1)];
        if (last2 == YM_DELIMITERS_CR && last1 == YM_DELIMITERS_LR) {
            NSData *lineBuffer = [data subdataWithRange:NSMakeRange(0, length - 2)];
            NSString *line = [[NSString alloc] initWithData:lineBuffer encoding:NSUTF8StringEncoding];
            if (!line) return nil;
            return [self _byAppendingHeaderLine:line];
        };
    }

    return nil;
}

- (NSHTTPURLResponse *)createHTTPURLResponseForURL:(NSURL *)URL {
    NSString *head = [_lines firstObject];
    if (!head) return nil;

    if ([_lines count] <= 1) return nil;
    NSArray *tail = [_lines subarrayWithRange:NSMakeRange(1, [_lines count] - 1)];

    NSArray *startline = [self statusLineFromLine:head];
    if (!startline) return nil;

    NSDictionary *headerFields = [self createHeaderFieldsFromLines:tail];
    if (!headerFields) return nil;

    NSString *v = startline[0];
    NSString *s = startline[1];
    return [[NSHTTPURLResponse alloc] initWithURL:URL
                                       statusCode:[s integerValue]
                                      HTTPVersion:v
                                     headerFields:headerFields];
}

/// Split a request line into its 3 parts: HTTP-Version SP Status-Code SP Reason-Phrase CRLF
/// - SeeAlso: https://tools.ietf.org/html/rfc2616#section-6.1
- (NSArray *)statusLineFromLine:(NSString *)line {
    NSArray *a = [line componentsSeparatedByString:@" "];
    if ([a count] != 3) return nil;

    NSString *s = a[1];

    NSInteger status = [s integerValue];
    if (status >= 100 && status <= 999) {
        return a;
    } else {
        return nil;
    }
}

- (NSDictionary *)createHeaderFieldsFromLines:(NSArray *)lines {
    // not same to swift's source
    NSMutableDictionary *headerFields = nil;
    for (NSString *line in lines) {
        NSRange r = [line rangeOfString:@":"];
        if (r.location != NSNotFound) {
            NSString *key = [line substringToIndex:r.location];
            NSString *value = [line substringFromIndex:r.location + 1];

            NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            NSString *trimKey = [key stringByTrimmingCharactersInSet:set];
            NSString *trimValue = [value stringByTrimmingCharactersInSet:set];
            if (trimKey && trimValue) {
                if (!headerFields) headerFields = [NSMutableDictionary dictionary];
                if (headerFields[trimKey]) {
                    NSString *v = [NSString stringWithFormat:@"%@ %@", headerFields[trimKey], trimValue];
                    [headerFields setObject:v forKey:trimKey];
                } else {
                    headerFields[trimKey] = trimValue;
                }
            }
        } else {
            continue;
        }
    }
    return [headerFields copy];
}

#pragma mark - Private Methods

- (instancetype)_byAppendingHeaderLine:(NSString *)line {
    YMParsedResponseHeader *header = [[YMParsedResponseHeader alloc] init];
    if (line.length == 0) {
        switch (_type) {
            case YMParsedResponseHeaderTypePartial: {
                header.type = YMParsedResponseHeaderTypeComplete;
                header.lines = _lines;
                return header;
            }
            case YMParsedResponseHeaderTypeComplete:
                return header;
        }
    } else {
        NSMutableArray *lines = [[self partialResponseHeader] mutableCopy];
        [lines addObject:line];

        header.type = YMParsedResponseHeaderTypePartial;
        header.lines = lines;

        return header;
    }
}

- (NSArray *)partialResponseHeader {
    switch (_type) {
        case YMParsedResponseHeaderTypeComplete:
            return [NSArray array];

        case YMParsedResponseHeaderTypePartial:
            return _lines;
    }
}

@end
