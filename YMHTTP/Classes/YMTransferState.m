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
        *error = [NSError errorWithDomain:@"YMHTTPParseSingleLineError" code:-1 userInfo:nil];
        return nil;
    }

    if (h.type == YMParsedResponseHeaderTypeComplete) {
        // TODO: lines
        [h createHTTPURLResponseForURL:_url];
        YMParsedResponseHeader *ph = [[YMParsedResponseHeader alloc] init];
        YMTransferState *ts = [[YMTransferState alloc] initWithURL:_url
                                              parsedResponseHeader:ph
                                                          response:_response
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
    [self createHTTPMessage];
    return nil;
}

- (NSString *)createHTTPMessage {
    NSString *head = [_lines firstObject];
    if (!head) return nil;

    if ([_lines count] <= 1) return nil;
    NSArray *tail = [_lines subarrayWithRange:NSMakeRange(1, [_lines count] - 1)];

    [self statusLineByLine:head];

    return nil;
}

/// Split a request line into its 3 parts: HTTP-Version SP Status-Code SP Reason-Phrase CRLF
/// - SeeAlso: https://tools.ietf.org/html/rfc2616#section-6.1

- (NSArray *)statusLineByLine:(NSString *)line {
    NSArray *a = [line componentsSeparatedByString:@" "];
    if ([a count] != 3) return nil;

    return a;
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
