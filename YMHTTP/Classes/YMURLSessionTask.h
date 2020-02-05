//
//  YMURLSessionTask.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import <Foundation/Foundation.h>

@class YMURLSession;

NS_ASSUME_NONNULL_BEGIN

@interface YMURLSessionTask : NSObject

@property (readonly) NSUInteger taskIdentifier;
@property (nullable, readonly, copy) NSURLRequest *originalRequest;
@property (nullable, readonly, copy) NSURLRequest *currentRequest;
@property (nullable, readonly, copy) NSURLResponse *response;

- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier;

- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier
                           body:(NSString *)body;

- (instancetype)init __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));
+ (instancetype)new __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));

@end

NS_ASSUME_NONNULL_END
