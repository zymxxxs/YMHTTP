//
//  YMTransferState.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>
#import "YMURLSessionTaskBodySource.h"

@class YMParsedResponseHeader;
@class YMDataDrain;
@class YMURLSessionTaskBodySource;

NS_ASSUME_NONNULL_BEGIN

@interface YMTransferState : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) YMParsedResponseHeader *parsedResponseHeader;
@property (nullable, nonatomic, strong) NSURLResponse *response;
@property (nullable, nonatomic, strong) id<YMURLSessionTaskBodySource> requestBodySource;
@property (nonatomic, strong) YMDataDrain *bodyDataDrain;

- (instancetype)initWithURL:(NSURL *)url bodyDataDrain:(YMDataDrain *)bodyDataDrain;

- (instancetype)initWithURL:(NSURL *)url
       parsedResponseHeader:(YMParsedResponseHeader *)parsedResponseHeader
                   response:(nullable NSURLResponse *)response
                 bodySource:(nullable id<YMURLSessionTaskBodySource>)bodySource
              bodyDataDrain:(YMDataDrain *)bodyDataDrain;

- (instancetype)initWithURL:(NSURL *)url
              bodyDataDrain:(YMDataDrain *)bodyDataDrain
                 bodySource:(nullable id<YMURLSessionTaskBodySource>)bodySource;

- (nullable YMTransferState *)byAppendingHTTPHeaderLineData:(NSData *)data error:(NSError **)error;

@end

typedef NS_ENUM(NSUInteger, YMDataDrainType) {
    YMDYMDataDraineInMemory,
    YMDataDrainTypeToFile,
    YMDataDrainTypeIgnore,
};

@interface YMDataDrain : NSObject

@property (nonatomic, assign) YMDataDrainType type;
@property (nullable, nonatomic, strong) NSData *data;
@property (nullable, nonatomic, strong) NSURL *fileURL;

@end

typedef NS_ENUM(NSUInteger, YMParsedResponseHeaderType) {
    YMParsedResponseHeaderTypePartial,
    YMParsedResponseHeaderTypeComplete
};

@interface YMParsedResponseHeader : NSObject

@property (nonatomic, assign) YMParsedResponseHeaderType type;
@property (nonatomic, strong) NSArray<NSString *> *lines;

- (nullable instancetype)byAppendingHeaderLine:(NSData *)data;

- (NSHTTPURLResponse *)createHTTPURLResponseForURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
