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
                   response:(NSHTTPURLResponse *)response
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

- (instancetype)byAppendingBodyData:(NSData *)bodyData {
    switch (_bodyDataDrain.type) {
        case YMDataDrainInMemory: {
            NSMutableData *data = _bodyDataDrain.data ? [_bodyDataDrain.data mutableCopy] : [NSMutableData data];
            [data appendData:bodyData];
            YMDataDrain *dataDrain = [[YMDataDrain alloc] init];
            dataDrain.type = YMDataDrainInMemory;
            dataDrain.data = data;
            return [[YMTransferState alloc] initWithURL:_url
                                   parsedResponseHeader:_parsedResponseHeader
                                               response:_response
                                             bodySource:_requestBodySource
                                          bodyDataDrain:dataDrain];
        }
        case YMDataDrainTypeToFile: {
            NSFileHandle *fileHandle = self.bodyDataDrain.fileHandle;
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:bodyData];
            return self;
        }
        case YMDataDrainTypeIgnore:
            return self;
    }
}

- (instancetype)byAppendingHTTPHeaderLineData:(NSData *)data error:(NSError **)error {
    YMParsedResponseHeader *h = [_parsedResponseHeader byAppendingHeaderLine:data];
    if (!h) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey : @"YMHTTPParseSingleLineError"}];
        }
        return nil;
    }

    if (h.type == YMParsedResponseHeaderTypeComplete) {
        NSHTTPURLResponse *response = [h createHTTPURLResponseForURL:_url];
        if (response == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey : @"YMHTTPParseCompleteHeaderError"}];
            }

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

- (BOOL)isHeaderComplete {
    return _response != nil;
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
    if ([a count] < 3) return nil;

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
            NSString *head = [line substringToIndex:r.location];
            NSString *tail = [line substringFromIndex:r.location + 1];

            NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            NSString *key = [head stringByTrimmingCharactersInSet:set];
            NSString *value = [tail stringByTrimmingCharactersInSet:set];
            if (key && value) {
                if (!headerFields) headerFields = [NSMutableDictionary dictionary];
                if (headerFields[key]) {
                    NSString *v = [NSString stringWithFormat:@"%@, %@", headerFields[key], value];
                    [headerFields setObject:v forKey:key];
                } else {
                    headerFields[key] = value;
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
