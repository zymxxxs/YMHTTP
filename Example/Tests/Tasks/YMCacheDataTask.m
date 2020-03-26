//
//  YMCacheDataTask.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/8.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMCacheDataTask.h"

@implementation YMCacheDataTask

- (void)YMURLSession:(YMURLSession *)session
                  task:(YMURLSessionTask *)task
    didReceiveResponse:(NSHTTPURLResponse *)response
     completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
    self.response = (NSHTTPURLResponse *)response;
    completionHandler(self.disposition);
    if (self.responseReceivedExpectation) {
        [self.responseReceivedExpectation fulfill];
    }
}

@end
