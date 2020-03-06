//
//  YMDataTask.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMDataTask.h"

@implementation YMDataTask

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation {
    self = [super init];
    if (self) {
        self.dataTaskExpectation = expectation;
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

-(void)runWithURL:(NSURL *)URL {
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.task = [session taskWithURL:URL];
    [self.task resume];
}

-(void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    self.result = value;
    self.args = value[@"args"];
}

//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
//    if (!self.responseReceivedExpectation) return;
//    [self.responseReceivedExpectation fulfill];
//}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.dataTaskExpectation fulfill];
    if (!error) return;
    if (self.cancelExpectation) {
        [self.cancelExpectation fulfill];
    }
        
    self.error = true;
}

- (void)cancel {
    [self.task cancel];
}

@end
