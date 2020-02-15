//
//  YMURLSessionTaskBodySource.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMURLSessionTaskBodySource.h"


@interface YMBodyStreamSource ()

@property (nonatomic, strong) NSInputStream *inputStream;

@end

@implementation YMBodyStreamSource

- (instancetype)initWithInputStream:(NSInputStream *)inputStream {
    if ([super init]) {
        _inputStream = inputStream;
    }
    return self;
}

- (void)getNextChunkWithLength:(NSInteger)length completionHandler:(void (^)(YMBodySourceDataChunk, NSData * _Nullable))completionHandler {
    if (!completionHandler) return;
    
    if (![_inputStream hasBytesAvailable]) {
        completionHandler(YMBodySourceDataChunkError, nil);
    }
    
    uint8_t buffer[length];
    NSInteger readBytes = [_inputStream read:buffer maxLength:length];
    if (readBytes > 0) {
        NSData *data = [[NSData alloc] initWithBytes:buffer
                                              length:length];
        completionHandler(YMBodySourceDataChunkData, data);
    } else if (readBytes == 0) {
        completionHandler(YMBodySourceDataChunkDone, nil);
    } else {
        completionHandler(YMBodySourceDataChunkError, nil);
    }
}

@end
