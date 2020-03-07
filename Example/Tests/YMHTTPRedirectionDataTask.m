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
    XCTAssertNotNil(response);
    XCTAssertEqual(302, response.statusCode, @"HTTP response code is not 302");
    completionHandler(request);
}

@end
