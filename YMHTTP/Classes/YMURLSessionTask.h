//
//  YMURLSessionTask.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import <Foundation/Foundation.h>

@class YMURLSession;
@class YMURLSessionTaskBody;

FOUNDATION_EXPORT const int64_t YMURLSessionTransferSizeUnknown;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YMURLSessionTaskState) {
    YMURLSessionTaskStateRunning = 0,
    YMURLSessionTaskStateSuspended = 1,
    YMURLSessionTaskStateCanceling = 2,
    YMURLSessionTaskStateCompleted = 3,
};

@interface YMURLSessionTask : NSObject <NSCopying>

@property (readonly) NSUInteger taskIdentifier;

@property (nullable, readonly, copy) NSURLRequest *originalRequest;

@property (nullable, readonly, copy) NSURLRequest *currentRequest;

@property (nullable, readonly, copy) NSHTTPURLResponse *response;

@property (nullable, readonly, copy) NSError *error;

@property (readonly) YMURLSessionTaskState state;

@property (readonly) int64_t countOfBytesReceived;

@property (readonly) int64_t countOfBytesSent;

@property (readonly) int64_t countOfBytesExpectedToSend;

@property (readonly) int64_t countOfBytesExpectedToReceive;

- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier;

- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier
                           body:(nullable YMURLSessionTaskBody *)body;

- (void)suspend;

- (void)resume;

- (void)cancel;

#pragma mark - Private

@property (readonly) BOOL isSuspendedAfterResume;

@end

NS_ASSUME_NONNULL_END
