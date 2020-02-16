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
    self = [super init];
    if (self) {
        _inputStream = inputStream;
    }
    return self;
}

- (void)getNextChunkWithLength:(NSInteger)length completionHandler:(void (^)(YMBodySourceDataChunk, NSData * _Nullable))completionHandler {
    if (!completionHandler) return;
    
    if (![_inputStream hasBytesAvailable]) {
        completionHandler(YMBodySourceDataChunkDone, nil);
        return;
    }
    
    uint8_t buffer[length];
    NSInteger readBytes = [_inputStream read:buffer maxLength:length];
    if (readBytes > 0) {
        NSLog(@"readBytes %@", @(readBytes));
        NSLog(@"length %@", @(length));
        NSData *data = [[NSData alloc] initWithBytes:buffer
                                              length:readBytes];
        completionHandler(YMBodySourceDataChunkData, data);
    } else if (readBytes == 0) {
        completionHandler(YMBodySourceDataChunkDone, nil);
    } else {
        completionHandler(YMBodySourceDataChunkError, nil);
    }
}

@end

@interface YMBodyDataSource ()

@property (nonatomic, strong)NSData *data;

@end


@implementation YMBodyDataSource

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
        _data = data;
    }
    return self;
}


- (void)getNextChunkWithLength:(NSInteger)length completionHandler:(nonnull void (^)(YMBodySourceDataChunk, NSData * _Nullable))completionHandler {
    if (!completionHandler) return;
     NSUInteger remaining = _data.length;
    if (remaining == 0) {
        completionHandler(YMBodySourceDataChunkDone, nil);
    } else if (remaining<=length) {
        NSData *r = [[NSData alloc] initWithData:_data];
        _data = nil;
        completionHandler(YMBodySourceDataChunkData, r);
    } else {
        NSData *chunk = [_data subdataWithRange:NSMakeRange(0, length)];
        NSData *remainder =[_data subdataWithRange:NSMakeRange(length-1, _data.length-length)];
        _data = remainder;
        completionHandler(YMBodySourceDataChunkData, chunk);
    }
    NSLog(@"readBytes %@", @(remaining));
    NSLog(@"length %@", @(length));
}

@end
