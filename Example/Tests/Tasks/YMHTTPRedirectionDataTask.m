//
//  YMHTTPRedirectionDataTask.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/6.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMHTTPRedirectionDataTask.h"

@implementation YMHTTPRedirectionDataTask

- (void)YMURLSession:(YMURLSession *)session
                          task:(YMURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *_Nullable))completionHandler {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    self.redirectionResponse = response;
    completionHandler(request);
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    [self.dataTaskExpectation fulfill];
    if (self.cancelExpectation) {
        [self.cancelExpectation fulfill];
    }

    self.error = error ? true : false;
    self.httpError = error;
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    NSString *last = (NSString *)self.callbacks.lastObject;
    if (![last isEqualToString:NSStringFromSelector(_cmd)]) {
        [self.callbacks addObject:NSStringFromSelector(_cmd)];
    }
    NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data
                                                          options:NSJSONReadingMutableContainers
                                                            error:nil];
    self.result = value;
}

- (void)YMURLSession:(YMURLSession *)session
                  task:(YMURLSessionTask *)task
    didReceiveResponse:(NSHTTPURLResponse *)response
     completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    self.response = response;
    completionHandler(YMURLSessionResponseAllow);
}

- (NSMutableArray *)callbacks {
    if (!_callbacks) {
        _callbacks = [NSMutableArray array];
    }
    return _callbacks;
}

@end
