//
//  YMTransferState.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMTransferState.h"

@implementation YMTransferState


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

-(instancetype)ByAppendingHeaderLine:(NSData *)data onHeaderCompleted:(BOOL (^)(NSString * _Nonnull))onHeaderCompleted {
//    if (data.length >=2 && [data subdataWithRange:NSMakeRange(data.length-2, 1)] == )
    NSArray
    return self;
}

@end
