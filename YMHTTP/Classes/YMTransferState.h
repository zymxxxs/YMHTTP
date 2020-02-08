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
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) id<YMURLSessionTaskBodySource> requestBodySource;
@property (nonatomic, assign) YMDataDrain *bodyDataDrain;

- (instancetype)initWithURL:(NSURL *)url dataDrain:(YMDataDrain *)dataDrain;

- (instancetype)initWithURL:(NSURL *)url
                  dataDrain:(YMDataDrain *)dataDrain
                 bodySource:(id<YMURLSessionTaskBodySource>)bodySource;

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
@property (nonatomic, strong) NSMutableArray<NSString *> *headerLines;

- (instancetype)ByAppendingHeaderLine:(NSData *)data
                    onHeaderCompleted:(BOOL (^)(NSString *headerLine))onHeaderCompleted;

@end

NS_ASSUME_NONNULL_END
