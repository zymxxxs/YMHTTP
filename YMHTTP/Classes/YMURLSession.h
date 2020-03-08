//
//  YMURLSession.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

#import <Foundation/Foundation.h>
#import "YMURLSessionDelegate.h"

@class YMURLSessionConfiguration;
@class YMURLSessionTaskBehaviour;
@class YMURLSessionTask;
@class YMEasyHandle;
@class YMTaskRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface YMURLSession : NSObject

/// The shared session uses the currently set global NSURLCache,
/// NSHTTPCookieStorage and NSURLCredentialStorage objects.
@property (class, readonly, strong) YMURLSession *sharedSession;

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration;

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration
                                  delegate:(nullable id<YMURLSessionDelegate>)delegate
                             delegateQueue:(nullable NSOperationQueue *)queue;

@property (readonly, strong) NSOperationQueue *delegateQueue;
@property (nullable, readonly, strong) id<YMURLSessionDelegate> delegate;
@property (readonly, copy) YMURLSessionConfiguration *configuration;
@property (nullable, copy) NSString *sessionDescription;
@property (readonly, nonatomic, strong) dispatch_queue_t workQueue;

- (void)finishTasksAndInvalidate;

- (void)invalidateAndCancel;

- (void)resetWithCompletionHandler:(void (^)(void))completionHandler;

- (void)flushWithCompletionHandler:(void (^)(void))completionHandler;

- (void)getAllTasksWithCompletionHandler:(void (^)(NSArray<__kindof YMURLSessionTask *> *tasks))completionHandler;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url connectToHost:(NSString *)host;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url connectToHost:(NSString *)host connectToPort:(NSInteger)port;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                    completionHandler:(void (^)(NSData *_Nullable data,
                                                NSHTTPURLResponse *_Nullable response,
                                                NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url
                completionHandler:(void (^)(NSData *_Nullable data,
                                            NSHTTPURLResponse *_Nullable response,
                                            NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url
                    connectToHost:(NSString *)host
                completionHandler:(void (^)(NSData *_Nullable data,
                                            NSHTTPURLResponse *_Nullable response,
                                            NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                             fromFile:(NSURL *)fileURL
                    completionHandler:(void (^)(NSData *_Nullable data,
                                                NSHTTPURLResponse *_Nullable response,
                                                NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                             fromData:(nullable NSData *)bodyData
                    completionHandler:(void (^)(NSData *_Nullable data,
                                                NSHTTPURLResponse *_Nullable response,
                                                NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithStreamedRequest:(NSURLRequest *)request;

- (YMURLSessionTask *)taskWithDownloadRequest:(NSURLRequest *)request;

- (YMURLSessionTask *)taskWithDownloadURL:(NSURL *)url;

- (YMURLSessionTask *)taskWithDownloadRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURL *_Nullable location,
                                                        NSHTTPURLResponse *_Nullable response,
                                                        NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithDownloadURL:(NSURL *)url
                        completionHandler:(void (^)(NSURL *_Nullable location,
                                                    NSHTTPURLResponse *_Nullable response,
                                                    NSError *_Nullable error))completionHandler;

#pragma mark - Private

@property (nonatomic, strong) YMTaskRegistry *taskRegistry;

- (YMURLSessionTaskBehaviour *)behaviourForTask:(YMURLSessionTask *)task;

- (void)addHandle:(YMEasyHandle *)handle;

- (void)removeHandle:(YMEasyHandle *)handle;

- (void)updateTimeoutTimerToValue:(NSInteger)value;

- (instancetype)init __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));
+ (instancetype)new __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));

@end

NS_ASSUME_NONNULL_END
