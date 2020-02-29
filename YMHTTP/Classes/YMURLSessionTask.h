//
//  YMURLSessionTask.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import <Foundation/Foundation.h>

@class YMURLSession;
@class YMURLSessionTaskBody;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YMURLSessionTaskState) {
    YMURLSessionTaskStateRunning = 0,
    YMURLSessionTaskStateSuspended = 1,
    YMURLSessionTaskStateCanceling = 2,
    YMURLSessionTaskStateCompleted = 3,
};

@interface YMURLSessionTask : NSObject

@property (readonly) NSUInteger taskIdentifier;
@property (nullable, readonly, copy) NSURLRequest *originalRequest;
@property (nullable, readonly, copy) NSURLRequest *currentRequest;
@property (nullable, readonly, copy) NSHTTPURLResponse *response;
@property (nullable, readonly, copy) NSError *error;
@property (readonly) YMURLSessionTaskState state;

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

@property (readonly, getter=isSuspendedAfterResume) BOOL isSuspendedAfterResume;

@end

NS_ASSUME_NONNULL_END
