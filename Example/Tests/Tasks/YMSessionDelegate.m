//
//  YMSessionDelegate.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMSessionDelegate.h"

@implementation YMSessionDelegate

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation {
    self = [super init];
    if (self) {
        self.expectation = expectation;
    }
    return self;
}

- (void)runWithRequest:(NSURLRequest *)request {
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.task = [session taskWithRequest:request];
    [self.task resume];
}

- (void)runWithURL:(NSURL *)URL {
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.task = [session taskWithURL:URL];
    [self.task resume];
}

- (void)YMURLSession:(YMURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    self.error = error;
    [self.invalidateExpectation fulfill];
}

- (NSMutableArray<NSString *> *)callbacks {
    if (!_callbacks) {
        _callbacks = [NSMutableArray array];
    }
    return _callbacks;
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    self.error = error;
    [self.expectation fulfill];
}

- (void)YMURLSession:(YMURLSession *)session
                 task:(YMURLSessionTask *)task
    needNewBodyStream:(void (^)(NSInputStream *_Nullable))completionHandler {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
}

- (void)YMURLSession:(YMURLSession *)session
                          task:(YMURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *_Nullable))completionHandler {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    self.redirectionResponse = response;

    if (self.redirectionHandler) {
        self.redirectionHandler(response, request, completionHandler);
    } else {
        completionHandler(request);
    }
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    NSString *last = (NSString *)self.callbacks.lastObject;
    if (![last isEqualToString:NSStringFromSelector(_cmd)]) {
        [self.callbacks addObject:NSStringFromSelector(_cmd)];
    }

    if (self.receivedData == nil) {
        self.receivedData = [data mutableCopy];
    } else {
        [self.receivedData appendData:data];
    }
}

- (void)YMURLSession:(YMURLSession *)session
                  task:(YMURLSessionTask *)task
    didReceiveResponse:(NSHTTPURLResponse *)response
     completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    self.response = response;
    completionHandler(YMURLSessionResponseAllow);
}

@end
