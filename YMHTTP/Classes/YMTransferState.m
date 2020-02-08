//
//  YMTransferState.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMTransferState.h"

@implementation YMTransferState

- (instancetype)initWithURL:(NSURL *)url dataDrain:(YMDataDrain *)dataDrain {
    self = [super init];
    if (self) {
        _url = url;
        _parsedResponseHeader = [[YMParsedResponseHeader alloc] init];
        _response = nil;
        _requestBodySource = nil;
        _bodyDataDrain = dataDrain;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
                  dataDrain:(YMDataDrain *)dataDrain
                 bodySource:(id<YMURLSessionTaskBodySource>)bodySource {
    self = [super init];
    if (self) {
        _url = url;
        _parsedResponseHeader = [[YMParsedResponseHeader alloc] init];
        _response = nil;
        _requestBodySource = bodySource;
        _bodyDataDrain = dataDrain;
    }
    return self;
}

@end

@implementation YMDataDrain

@end

@implementation YMParsedResponseHeader

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = YMParsedResponseHeaderTypePartial;
        _headerLines = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)ByAppendingHeaderLine:(NSData *)data onHeaderCompleted:(BOOL (^)(NSString *_Nonnull))onHeaderCompleted {
    //    if (data.length >=2 && [data subdataWithRange:NSMakeRange(data.length-2, 1)] == )
    return self;
}

@end
