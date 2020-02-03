//
//  YMURLSession.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

#import <Foundation/Foundation.h>

@class YMURLSessionConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface YMURLSession : NSObject

/// The shared session uses the currently set global NSURLCache,
/// NSHTTPCookieStorage and NSURLCredentialStorage objects.
@property (class, readonly, strong) YMURLSession *sharedSession;

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration;

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration
                                  delegate:(nullable id<NSURLSessionDelegate>)delegate
                             delegateQueue:(nullable NSOperationQueue *)queue;

@property (readonly, retain) NSOperationQueue *delegateQueue;
@property (nullable, readonly, retain) id<NSURLSessionDelegate> delegate;
@property (readonly, copy) YMURLSessionConfiguration *configuration;
@property (nullable, copy) NSString *sessionDescription;

- (instancetype)init __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));
+ (instancetype)new __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));

@end

NS_ASSUME_NONNULL_END
