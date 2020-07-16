//
//  TestURLSesssionDirect.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/26.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <YMHTTP/YMHTTP.h>
#import "YMHTTPRedirectionDataTask.h"
#import "YMSessionDelegate.h"

@interface TestURLSesssionDirect : XCTestCase

@end

@implementation TestURLSesssionDirect

- (void)testHttpRedirectionWithCode300 {
    NSArray *httpMethods = @[ @"HEAD", @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = @"http://0.0.0.0/redirect-to?url=%2Fget&status_code=300";
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;
        XCTestExpectation *te = [self
            expectationWithDescription:[NSString
                                           stringWithFormat:@"%@ testHttpRedirectionWithCode300: with HTTP redirection",
                                                            method]];
        YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
        [d runWithRequest:request];
        [self waitForExpectationsWithTimeout:12 handler:nil];
        XCTAssertNil(d.httpError);
        XCTAssertNil(d.redirectionResponse);
        XCTAssertNotNil(d.response);
        XCTAssertEqual(d.response.statusCode, 300);

        XCTAssertEqual(d.callbacks.count, 2);
        XCTAssertEqualObjects(d.callbacks[0],
                              NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
        XCTAssertEqualObjects(d.callbacks[1], NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
    }
}

- (void)testHttpRedirectionWithCode301_302 {
    NSArray *httpMethods = @[ @"POST", @"HEAD", @"GET", @"PUT", @"DELETE" ];
    for (NSNumber *statusCode in @[ @(301), @(302) ]) {
        for (NSString *method in httpMethods) {
            NSString *urlString = [NSString
                stringWithFormat:@"http://0.0.0.0/redirect-to?url=/anything&status_code=%@", statusCode.stringValue];
            NSURL *url = [NSURL URLWithString:urlString];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.HTTPMethod = method;
            XCTestExpectation *te =
                [self expectationWithDescription:
                          [NSString stringWithFormat:@"%@ %@ testHttpRedirectionWithCode301_302: with HTTP redirection",
                                                     method,
                                                     statusCode.stringValue]];
            YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
            [d runWithRequest:request];
            [self waitForExpectationsWithTimeout:12 handler:nil];
            XCTAssertNil(d.httpError);
            XCTAssertEqual(d.response.statusCode, 200);
            XCTAssertEqual(d.redirectionResponse.statusCode, statusCode.integerValue);

            if ([method isEqualToString:@"HEAD"]) {
                XCTAssertEqual(d.callbacks.count, 3);
                XCTAssertEqualObjects(d.callbacks[0],
                                      NSStringFromSelector(@selector(
                                          YMURLSession:
                                                  task:willPerformHTTPRedirection:newRequest:completionHandler:)));
                XCTAssertEqualObjects(
                    d.callbacks[1],
                    NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
                XCTAssertEqualObjects(d.callbacks[2],
                                      NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
                XCTAssertNil(d.result);
            } else {
                XCTAssertEqual(d.callbacks.count, 4);
                XCTAssertEqualObjects(d.callbacks[0],
                                      NSStringFromSelector(@selector(
                                          YMURLSession:
                                                  task:willPerformHTTPRedirection:newRequest:completionHandler:)));
                XCTAssertEqualObjects(
                    d.callbacks[1],
                    NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
                XCTAssertEqualObjects(d.callbacks[2],
                                      NSStringFromSelector(@selector(YMURLSession:task:didReceiveData:)));
                XCTAssertEqualObjects(d.callbacks[3],
                                      NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
                XCTAssertEqualObjects(d.task.currentRequest.HTTPMethod,
                                      [method isEqualToString:@"POST"] ? @"GET" : method);
            }
        }
    }
}

- (void)testHttpRedirectionWithCode303 {
    NSArray *httpMethods = @[ @"POST", @"HEAD", @"GET", @"PUT", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = @"http://0.0.0.0/redirect-to?url=/anything&status_code=303";
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;
        XCTestExpectation *te = [self
            expectationWithDescription:[NSString
                                           stringWithFormat:@"%@ testHttpRedirectionWithCode303: with HTTP redirection",
                                                            method]];
        YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
        [d runWithRequest:request];
        [self waitForExpectationsWithTimeout:12 handler:nil];
        XCTAssertNil(d.httpError);
        XCTAssertEqual(d.response.statusCode, 200);
        XCTAssertEqual(d.redirectionResponse.statusCode, 303);
        XCTAssertEqual(d.callbacks.count, 4);
        XCTAssertEqualObjects(
            d.callbacks[0],
            NSStringFromSelector(@selector(YMURLSession:
                                                   task:willPerformHTTPRedirection:newRequest:completionHandler:)));
        XCTAssertEqualObjects(d.callbacks[1],
                              NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
        XCTAssertEqualObjects(d.callbacks[2], NSStringFromSelector(@selector(YMURLSession:task:didReceiveData:)));
        XCTAssertEqualObjects(d.callbacks[3], NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
        XCTAssertEqualObjects(d.task.currentRequest.HTTPMethod, @"GET");
    }
}

- (void)testHttpRedirectionWithCode304 {
    NSArray *httpMethods = @[ @"HEAD", @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = @"http://0.0.0.0/redirect-to?url=%2Fget&status_code=304";
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;
        XCTestExpectation *te = [self
            expectationWithDescription:[NSString
                                           stringWithFormat:@"%@ testHttpRedirectionWithCode300: with HTTP redirection",
                                                            method]];
        YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
        [d runWithRequest:request];
        [self waitForExpectationsWithTimeout:12 handler:nil];
        XCTAssertNil(d.httpError);
        XCTAssertNil(d.redirectionResponse);
        XCTAssertNotNil(d.response);
        XCTAssertEqual(d.response.statusCode, 304);

        XCTAssertEqual(d.callbacks.count, 2);
        XCTAssertEqualObjects(d.callbacks[0],
                              NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
        XCTAssertEqualObjects(d.callbacks[1], NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
        XCTAssertNil(d.result);
    }
}

- (void)testHttpRedirectionWithCode305_308 {
    NSArray *httpMethods = @[ @"POST", @"HEAD", @"GET", @"PUT", @"DELETE" ];
    for (NSNumber *statusCode in @[ @(305), @(306), @(307), @(308) ]) {
        for (NSString *method in httpMethods) {
            NSString *urlString = [NSString
                stringWithFormat:@"http://0.0.0.0/redirect-to?url=/anything&status_code=%@", statusCode.stringValue];
            NSURL *url = [NSURL URLWithString:urlString];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.HTTPMethod = method;
            XCTestExpectation *te =
                [self expectationWithDescription:
                          [NSString stringWithFormat:@"%@ %@ testHttpRedirectionWithCode305_308: with HTTP redirection",
                                                     method,
                                                     statusCode.stringValue]];
            YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
            [d runWithRequest:request];
            [self waitForExpectationsWithTimeout:50 handler:nil];
            XCTAssertNil(d.httpError);
            XCTAssertEqual(d.response.statusCode, 200);
            XCTAssertEqual(d.redirectionResponse.statusCode, statusCode.integerValue);

            if ([method isEqualToString:@"HEAD"]) {
                XCTAssertEqual(d.callbacks.count, 3);
                XCTAssertEqualObjects(d.callbacks[0],
                                      NSStringFromSelector(@selector(
                                          YMURLSession:
                                                  task:willPerformHTTPRedirection:newRequest:completionHandler:)));
                XCTAssertEqualObjects(
                    d.callbacks[1],
                    NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
                XCTAssertEqualObjects(d.callbacks[2],
                                      NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
                XCTAssertNil(d.result);
            } else {
                XCTAssertEqual(d.callbacks.count, 4);
                XCTAssertEqualObjects(d.callbacks[0],
                                      NSStringFromSelector(@selector(
                                          YMURLSession:
                                                  task:willPerformHTTPRedirection:newRequest:completionHandler:)));
                XCTAssertEqualObjects(
                    d.callbacks[1],
                    NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
                XCTAssertEqualObjects(d.callbacks[2],
                                      NSStringFromSelector(@selector(YMURLSession:task:didReceiveData:)));
                XCTAssertEqualObjects(d.callbacks[3],
                                      NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
                XCTAssertEqualObjects(d.task.currentRequest.HTTPMethod, method);
            }
        }
    }
}

- (void)testHttpRedirectionWithCompleteRelativePath {
    NSString *urlString = @"http://0.0.0.0/redirect-to?url=http%3A%2F%2F0.0.0.0%2Fget";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testHttpRedirectionWithCompleteRelativePath: with HTTP redirection"];
    YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertEqualObjects(d.result[@"url"],
                              @"http://0.0.0.0/get",
                              @"testHttpRedirectionWithCompleteRelativePath returned an unexpected result");
    }
}

- (void)testHttpRedirectionWithInCompleteRelativePath {
    NSString *urlString = @"http://0.0.0.0/redirect-to?url=%2Fget";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testHttpRedirectionWithInCompleteRelativePath: with HTTP redirection"];
    YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertEqualObjects(d.result[@"url"],
                              @"http://0.0.0.0/get",
                              @"testHttpRedirectionWithCompleteRelativePath returned an unexpected result");
    }
}

- (void)testHttpRedirectionTimeout {
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testHttpRedirectionTimeout: timeout with redirection"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"http://0.0.0.0/redirect-to?url=%2Fdelay%2F10";
    NSURL *url = [NSURL URLWithString:urlString];

    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                if (!error) {
                    XCTFail("must fail");
                } else {
                    XCTAssertEqual(error.code, NSURLErrorTimedOut, @"Unexpected error code");
                }
                [te fulfill];
            }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testHttpRedirectDontFollowUsingNil {
    NSArray *httpMethods = @[ @"HEAD", @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = [NSString stringWithFormat:@"http://0.0.0.0/redirect-to?url=/anything&status_code=302"];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;

        XCTestExpectation *te = [self
            expectationWithDescription:[NSString
                                           stringWithFormat:@"%@ testHttpRedirectDontFollowUsingNil: with redirection",
                                                            method]];
        YMSessionDelegate *d = [[YMSessionDelegate alloc] initWithExpectation:te];
        d.redirectionHandler = ^(NSHTTPURLResponse *_Nonnull response,
                                 NSURLRequest *_Nonnull request,
                                 void (^_Nonnull completionHandler)(NSURLRequest *)) {
            completionHandler(nil);
        };
        [d runWithRequest:request];

        [self waitForExpectationsWithTimeout:10.f handler:nil];
        XCTAssertNotNil(d.response);
        XCTAssertEqual(d.response.statusCode, 302);
        XCTAssertEqual(d.redirectionResponse.statusCode, 302);
        XCTAssertEqual(d.callbacks.count, 3);
        XCTAssertEqualObjects(
            d.callbacks[0],
            NSStringFromSelector(@selector(YMURLSession:
                                                   task:willPerformHTTPRedirection:newRequest:completionHandler:)));
        XCTAssertEqualObjects(d.callbacks[1],
                              NSStringFromSelector(@selector(YMURLSession:task:didReceiveResponse:completionHandler:)));
        XCTAssertEqualObjects(d.callbacks[2], NSStringFromSelector(@selector(YMURLSession:task:didCompleteWithError:)));
        XCTAssertNil(d.receivedData);
    }
}

- (void)testHttpRedirectDontFollowIgnoringHandler {
    NSArray *httpMethods = @[ @"HEAD", @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = [NSString stringWithFormat:@"http://0.0.0.0/redirect-to?url=/anything&status_code=302"];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;
        request.timeoutInterval = 2.f;
        XCTestExpectation *te = [self
            expectationWithDescription:
                [NSString stringWithFormat:@"%@ testHttpRedirectDontFollowIgnoringHandler: with redirection", method]];
        [te setInverted:true];
        YMSessionDelegate *d = [[YMSessionDelegate alloc] initWithExpectation:te];
        d.redirectionHandler = ^(NSHTTPURLResponse *_Nonnull response,
                                 NSURLRequest *_Nonnull request,
                                 void (^_Nonnull completionHandler)(NSURLRequest *)) {

        };
        [d runWithRequest:request];

        [self waitForExpectationsWithTimeout:3.f handler:nil];
        XCTAssertNil(d.error);
        XCTAssertNil(d.receivedData);
        XCTAssertNil(d.response);
        XCTAssertEqual(d.redirectionResponse.statusCode, 302);
        XCTAssertEqual(d.callbacks.count, 1);
        XCTAssertEqualObjects(
            d.callbacks[0],
            NSStringFromSelector(@selector(YMURLSession:
                                                   task:willPerformHTTPRedirection:newRequest:completionHandler:)));
    }
}

- (void)testHttpRedirectionChainInheritsTimeoutInterval {
    NSArray *httpMethods = @[ @"HEAD", @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = [NSString stringWithFormat:@"http://0.0.0.0/redirect-to?url=/anything&status_code=302"];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = method;
        request.timeoutInterval = 3.f;

        XCTestExpectation *te = [self
            expectationWithDescription:
                [NSString
                    stringWithFormat:@"%@ testHttpRedirectionChainInheritsTimeoutInterval: with redirection", method]];
        NSMutableArray *timeoutIntervals = [NSMutableArray array];
        YMSessionDelegate *d = [[YMSessionDelegate alloc] initWithExpectation:te];
        d.redirectionHandler = ^(NSHTTPURLResponse *_Nonnull response,
                                 NSURLRequest *_Nonnull request,
                                 void (^_Nonnull completionHandler)(NSURLRequest *)) {
            [timeoutIntervals addObject:@(request.timeoutInterval)];
            completionHandler(request);
        };
        [d runWithRequest:request];
        [self waitForExpectationsWithTimeout:6.f handler:nil];
        XCTAssertEqual(timeoutIntervals.count, 1);
        XCTAssertEqualObjects(timeoutIntervals[0], @(3.f));
        XCTAssertEqual(d.response.statusCode, 200);
    }
}

- (void)testHttpRedirectionExceededMaxRedirects {
    NSString *urlString = [NSString stringWithFormat:@"http://0.0.0.0/redirect/18"];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 3.f;

    XCTestExpectation *te =
        [self expectationWithDescription:@"testHttpRedirectionExceededMaxRedirects: with redirection"];
    NSMutableArray *redirectRequests = [NSMutableArray array];
    YMSessionDelegate *d = [[YMSessionDelegate alloc] initWithExpectation:te];
    d.redirectionHandler = ^(NSHTTPURLResponse *_Nonnull response,
                             NSURLRequest *_Nonnull request,
                             void (^_Nonnull completionHandler)(NSURLRequest *)) {
        [redirectRequests addObject:response];
        completionHandler(request);
    };
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:30.f handler:nil];
    XCTAssertNil(d.response);
    XCTAssertNotNil(d.receivedData);
    XCTAssertNotNil(d.error);
    XCTAssertEqual(d.error.code, NSURLErrorHTTPTooManyRedirects);
    XCTAssertEqualObjects(d.error.localizedDescription, @"too many HTTP redirects");
    XCTAssertEqual(((NSHTTPURLResponse *)redirectRequests.lastObject).statusCode, 302);
}

@end
