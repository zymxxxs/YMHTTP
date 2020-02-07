//
//  YMURLSessionDelegate.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>

@class YMURLSessionTask;
@class YMURLSession;

NS_ASSUME_NONNULL_BEGIN

@protocol YMURLSessionDelegate <NSObject>

@end

@protocol YMURLSessionTaskDelegate <NSURLSessionDelegate>


@optional
- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task
needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler;


@end

NS_ASSUME_NONNULL_END
