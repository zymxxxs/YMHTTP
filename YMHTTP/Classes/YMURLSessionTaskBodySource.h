//
//  YMURLSessionTaskBodySource.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YMBodySourceDataChunk) {
    YMBodySourceDataChunkData,
    YMBodySourceDataChunkDone,
    YMBodySourceDataChunkRetryLater,
    YMBodySourceDataChunkError
};

NS_ASSUME_NONNULL_BEGIN

@protocol YMURLSessionTaskBodySource <NSObject>

- (void)getNextChunkWithLength:(NSInteger)length
             completionHandler:(void (^)(YMBodySourceDataChunk chunk, NSData* _Nullable data))completionHandler;
@end

@interface YMBodyStreamSource : NSObject

@end

NS_ASSUME_NONNULL_END
