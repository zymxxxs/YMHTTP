//
//  YMURLSessionDelegate.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>

@class YMURLSessionTask;
@class YMURLSession;

typedef NS_ENUM(NSInteger, YMURLSessionResponseDisposition) {
    YMURLSessionResponseCancel = 0, /* Cancel the load, this is the same as -[task cancel] */
    YMURLSessionResponseAllow = 1,
};

NS_ASSUME_NONNULL_BEGIN

@protocol YMURLSessionDelegate <NSObject>
@optional
- (void)YMURLSession:(YMURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error;

@end

@protocol YMURLSessionTaskDelegate <YMURLSessionDelegate>

@optional
- (void)YMURLSession:(YMURLSession *)session
                 task:(YMURLSessionTask *)task
    needNewBodyStream:(void (^)(NSInputStream *_Nullable bodyStream))completionHandler;

- (void)YMURLSession:(YMURLSession *)session
                          task:(YMURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *_Nullable))completionHandler;

- (void)YMURLSession:(YMURLSession *)session
                    task:(YMURLSessionTask *)task
    didCompleteWithError:(nullable NSError *)error;

@end

@protocol YMURLSessionDataDelegate <YMURLSessionTaskDelegate>

@optional

- (void)YMURLSession:(YMURLSession *)session
                  task:(YMURLSessionTask *)task
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(YMURLSessionResponseDisposition disposition))completionHandler;

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
