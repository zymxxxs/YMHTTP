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

- (instancetype)init __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));
+ (instancetype)new __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));

@end

NS_ASSUME_NONNULL_END
