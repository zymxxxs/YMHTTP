//
//  YMURLSessionCacheTests.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/8.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <YMHTTP/YMHTTP.h>
#import "YMCacheDataTask.h"

@interface YMURLSessionCacheTests : XCTestCase

@end

@implementation YMURLSessionCacheTests

- (void)resetURLCache {
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:0 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
}

- (void)testCacheUseProtocolCachePolicy {
    [self resetURLCache];

    NSString *urlString = @"http://httpbin.org/cache/200";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    XCTestExpectation *te = [self expectationWithDescription:@"GET testCacheUseProtocolCachePolicy: with a delegate"];
    YMCacheDataTask *d = [[YMCacheDataTask alloc] initWithExpectation:te];
    d.responseReceivedExpectation = [self expectationWithDescription:@"GET responseReceivedExpectation"];
    d.disposition = YMURLSessionResponseAllow;
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d.error) {
        NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
        XCTAssertNotNil(cachedURLResponse);
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d.response.allHeaderFields);
    } else {
        XCTFail();
    }

    XCTestExpectation *te1 = [self expectationWithDescription:@"GET testCacheUseProtocolCachePolicy1: with a delegate"];
    YMCacheDataTask *d1 = [[YMCacheDataTask alloc] initWithExpectation:te1];
    d1.responseReceivedExpectation = [self expectationWithDescription:@"GET responseReceivedExpectation1"];
    d1.disposition = YMURLSessionResponseAllow;
    [d1 runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d1.error) {
        NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
        XCTAssertNotNil(cachedURLResponse);
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d1.response.allHeaderFields);
    } else {
        XCTFail();
    }
}

- (void)testCacheUseIgnoringLocalCacheData {
    [self resetURLCache];

    NSString *urlString = @"http://httpbin.org/cache/200";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testCacheUseIgnoringLocalCacheData: with a delegate"];
    YMCacheDataTask *d = [[YMCacheDataTask alloc] initWithExpectation:te];
    d.disposition = YMURLSessionResponseAllow;
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d.error) {
        NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
        XCTAssertNotNil(cachedURLResponse);
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d.response.allHeaderFields);
    } else {
        XCTFail();
    }

    NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    XCTAssertNotNil(cachedURLResponse);
    sleep(1);

    XCTestExpectation *te1 = [self expectationWithDescription:@"GET testCacheUseProtocolCachePolicy1: with a delegate"];
    YMCacheDataTask *d1 = [[YMCacheDataTask alloc] initWithExpectation:te1];
    d1.disposition = YMURLSessionResponseAllow;
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [d1 runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d1.error) {
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertNotEqualObjects(response.allHeaderFields, d1.response.allHeaderFields);
        XCTAssertNotEqualObjects(response.allHeaderFields[@"Date"], d1.response.allHeaderFields[@"Date"]);
    } else {
        XCTFail();
    }
}

- (void)testCacheUseReturnCacheDataElseLoad {
    [self resetURLCache];

    NSString *urlString = @"http://httpbin.org/cache/200";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testCacheUseReturnCacheDataElseLoad: with a delegate"];
    YMCacheDataTask *d = [[YMCacheDataTask alloc] initWithExpectation:te];
    d.disposition = YMURLSessionResponseAllow;
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d.error) {
        NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
        XCTAssertNotNil(cachedURLResponse);
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d.response.allHeaderFields);
    } else {
        XCTFail();
    }

    NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    XCTAssertNotNil(cachedURLResponse);

    XCTestExpectation *te1 =
        [self expectationWithDescription:@"GET testCacheUseReturnCacheDataElseLoad 1: with a delegate"];
    YMCacheDataTask *d1 = [[YMCacheDataTask alloc] initWithExpectation:te1];
    d1.disposition = YMURLSessionResponseAllow;
    request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    [d1 runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d1.error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d1.response.allHeaderFields);
    } else {
        XCTFail();
    }

    [self resetURLCache];
    XCTAssertNil([[NSURLCache sharedURLCache] cachedResponseForRequest:request]);
    sleep(2);

    XCTestExpectation *te2 =
        [self expectationWithDescription:@"GET testCacheUseReturnCacheDataElseLoad 2: with a delegate"];
    YMCacheDataTask *d2 = [[YMCacheDataTask alloc] initWithExpectation:te2];
    d2.disposition = YMURLSessionResponseAllow;
    request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    [d2 runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d2.error) {
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertNotEqualObjects(response.allHeaderFields, d2.response.allHeaderFields);
        XCTAssertNotEqualObjects(response.allHeaderFields[@"Date"], d2.response.allHeaderFields[@"Date"]);
    } else {
        XCTFail();
    }
}

- (void)testCacheUseReturnCacheDataDontLoad {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];

    NSString *urlString = @"http://httpbin.org/cache/200";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testCacheUseReturnCacheDataDontLoad: with a delegate"];
    YMCacheDataTask *d = [[YMCacheDataTask alloc] initWithExpectation:te];
    d.disposition = YMURLSessionResponseAllow;
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d.error) {
        NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
        XCTAssertNotNil(cachedURLResponse);
        XCTAssertTrue([cachedURLResponse.response isKindOfClass:[NSHTTPURLResponse class]]);
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d.response.allHeaderFields);
    } else {
        XCTFail();
    }

    NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    XCTAssertNotNil(cachedURLResponse);

    XCTestExpectation *te1 =
        [self expectationWithDescription:@"GET testCacheUseReturnCacheDataDontLoad 1: with a delegate"];
    YMCacheDataTask *d1 = [[YMCacheDataTask alloc] initWithExpectation:te1];
    d1.disposition = YMURLSessionResponseAllow;
    request.cachePolicy = NSURLRequestReturnCacheDataDontLoad;
    [d1 runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d1.error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedURLResponse.response;
        XCTAssertEqualObjects(response.allHeaderFields, d1.response.allHeaderFields);
    } else {
        XCTFail();
    }

    [self resetURLCache];
    XCTAssertNil([[NSURLCache sharedURLCache] cachedResponseForRequest:request]);

    XCTestExpectation *te2 =
        [self expectationWithDescription:@"GET testCacheUseReturnCacheDataDontLoad 2: with a delegate"];
    YMCacheDataTask *d2 = [[YMCacheDataTask alloc] initWithExpectation:te2];
    d2.disposition = YMURLSessionResponseAllow;
    request.cachePolicy = NSURLRequestReturnCacheDataDontLoad;
    [d2 runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    XCTAssertTrue(d2.error);
}

- (void)testCacheUsingResponseAllow {
    [self resetURLCache];

    NSString *urlString = @"http://httpbin.org/get";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    XCTestExpectation *te = [self expectationWithDescription:@"GET testCacheUsingResponseAllow: with a delegate"];
    YMCacheDataTask *d = [[YMCacheDataTask alloc] initWithExpectation:te];
    d.responseReceivedExpectation = [self expectationWithDescription:@"GET responseReceivedExpectation"];
    d.disposition = YMURLSessionResponseCancel;
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];

    if (!d.error) {
        XCTFail();
    } else {
        XCTAssertEqual(d.task.error.code, NSURLErrorCancelled);
    }
}

@end
