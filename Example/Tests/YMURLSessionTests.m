//
//  YMURLSessionTests.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "YMDataTask.h"
#import "YMDownloadTask.h"
#import <YMHTTP/YMHTTP.h>
#import "YMSessionDelegate.h"

@interface YMURLSessionTests : XCTestCase

@end

@implementation YMURLSessionTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDataTaskWithURL {
    NSString *urlString = @"http://httpbin.org/get?capital=testDataTaskWithURL";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te = [self expectationWithDescription:@"GET testDataTaskWithURL: with a delegate"];
    YMDataTask *d = [[YMDataTask alloc] initWithExpectation:te];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertEqualObjects(d.args[@"capital"], @"testDataTaskWithURL", @"test_dataTaskWithURLRequest returned an unexpected result");
    }
}

- (void)testDataTaskWithURLCompletionHandler {
    [self dataTaskWithURLCompletionHandlerWithSession:[YMURLSession sharedSession]];
    
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    [self dataTaskWithURLCompletionHandlerWithSession:session];
}

- (void)dataTaskWithURLCompletionHandlerWithSession:(YMURLSession *)session {
    NSString *urlString = @"http://httpbin.org/get?capital=China";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te = [self expectationWithDescription:@"GET dataTaskWithURLCompletionHandlerWithSession: with a completion handler"];
    YMURLSessionTask *task = [session taskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertNotNil(data);
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) return ;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        XCTAssertEqual(httpResponse.statusCode, 200, "HTTP response code is not 200");
        
        NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        NSDictionary *args = value[@"args"] ?: @{};
        XCTAssertEqualObjects(args[@"capital"], @"China", "Did not receive expected value");
        [te fulfill];
    }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testDataTaskWithRequest {
    NSString *urlString = @"http://httpbin.org/get?capital=testDataTaskWithRequest";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    XCTestExpectation *te = [self expectationWithDescription:@"GET testDataTaskWithRequest: with a delegate"];
    YMDataTask *d = [[YMDataTask alloc] initWithExpectation:te];
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertEqualObjects(d.args[@"capital"], @"testDataTaskWithRequest", @"test_dataTaskWithURLRequest returned an unexpected result");
    }
}

- (void)testDataTaskWithURLRequestCompletionHandler {
    NSString *urlString = @"http://httpbin.org/get?capital=testDataTaskWithURLRequestCompletionHandler";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te = [self expectationWithDescription:@"GET testDataTaskWithURLRequestCompletionHandler: with a completion handler"];
    
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertNotNil(data);
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) return ;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        XCTAssertEqual(httpResponse.statusCode, 200, "HTTP response code is not 200");
        
        NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        NSDictionary *args = value[@"args"] ?: @{};
        XCTAssertEqualObjects(args[@"capital"], @"testDataTaskWithURLRequestCompletionHandler", "Did not receive expected value");
        [te fulfill];
    }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testDataTaskWithHttpInputStream {
    NSString *urlString = @"http://httpbin.org/post";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"chunked" forHTTPHeaderField:@"Transfer-Encoding"];
    
    NSString *dataString = @"testDataTaskWithHttpInputStream";
    NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        XCTFail();
        return;
    }
    request.HTTPBodyStream = [[NSInputStream alloc] initWithData:data];
    [request.HTTPBodyStream open];
    
    
    XCTestExpectation *te = [self expectationWithDescription:@"POST testDataTaskWithHttpInputStream: with HTTP Body as InputStream"];
    
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config];
    YMURLSessionTask *task = [session taskWithRequest:request completionHandler:^(NSData * _Nullable responseData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertNotNil(data);
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            XCTFail("response is invalid");
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        XCTAssertEqual(httpResponse.statusCode, 200, @"HTTP response code is not 200");
        
        NSDictionary *value = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:nil];
        NSString *v = value[@"data"] ?: @"";
        XCTAssertEqualObjects(v, dataString, @"Response Data and Data is not equal");
        [te fulfill];
    }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testGzippedDataTask {
    NSString *urlString = @"http://httpbin.org/gzip";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te = [self expectationWithDescription:@"GET testGzippedDataTask: with a delegate"];
    YMDataTask *d = [[YMDataTask alloc] initWithExpectation:te];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertTrue(d.result[@"gzipped"], @"testGzippedDataTask returned an unexpected result");
    }
}

- (void)testDownloadTaskWithURL {
    NSString *urlString = @"http://httpbin.org/image/png";
    NSURL *url = [NSURL URLWithString:urlString];
    YMDownloadTask *d = [[YMDownloadTask alloc] initWithTestCase:self description:@"Download GET testDownloadTaskWithURL: with a delegate"];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testDownloadTaskWithRequest {
    NSString *urlString = @"http://httpbin.org/image/jepg";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    YMDownloadTask *d = [[YMDownloadTask alloc] initWithTestCase:self description:@"Download GET testDownloadTaskWithRequest: with a delegate"];
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testDownloadTaskWithRequestAndHandler {
    [self downloadTaskWithRequestAndHandlerWithSession:[YMURLSession sharedSession]];
    
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    [self downloadTaskWithRequestAndHandlerWithSession:session];
}

- (void)downloadTaskWithRequestAndHandlerWithSession:(YMURLSession *)session {
    XCTestExpectation *te = [self expectationWithDescription:@"Download GET downloadTaskWithRequestAndHandlerWithSession: with a completion handler"];
    NSString *urlString = @"http://httpbin.org/image/svg";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    YMURLSessionTask *task = [session taskWithDownloadRequest:request
                    completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        
        NSError *e = nil;
        [[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:&e];
        XCTAssertNil(e);
        [te fulfill];
    }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testDownloadTaskWithURLAndHandler {
    XCTestExpectation *te = [self expectationWithDescription:@"Download GET testDownloadTaskWithURLAndHandler: with a completion handler"];
    NSString *urlString = @"http://httpbin.org/image/webp";
    NSURL *url = [NSURL URLWithString:urlString];
    
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithDownloadURL:url
                    completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            XCTAssertEqual(error.code, -1001, @"Unexpected error code");
        }
        
        NSError *e = nil;
        [[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:&e];
        XCTAssertNil(e);
        [te fulfill];
    }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testGzippedDownloadTask {
    NSString *urlString = @"http://httpbin.org/image/gzip";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    YMDownloadTask *d = [[YMDownloadTask alloc] initWithTestCase:self description:@"Download GET testGzippedDownloadTask: with a delegate"];
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testFinishTasksAndInvalidate {
    XCTestExpectation *invalidateExpectation = [self expectationWithDescription:@"Session invalidation"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"GET testFinishTasksAndInvalidate: task completion before session invalidation"];
    
    NSString *urlString = @"http://httpbin.org/get";
    NSURL *url = [NSURL URLWithString:urlString];
    YMSessionDelegate *delegate = [YMSessionDelegate new];
    delegate.invalidateExpectation = invalidateExpectation;
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [completionExpectation fulfill];
    }];
    [task resume];
    [session finishTasksAndInvalidate];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testTaskError {
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"GET testTaskError: Bad URL error"];
    
    NSString *urlString = @"http://192.168.0.1:-1/";
    NSURL *url = [NSURL URLWithString:urlString];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, NSURLErrorBadURL);
        [completionExpectation fulfill];
    }];
    [task resume];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.code, NSURLErrorBadURL);
    }];
}

- (void)testTaskCopy {
    NSString *urlString = @"http://httpbin.org/get";
    NSURL *url = [NSURL URLWithString:urlString];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    
    YMURLSessionTask *task = [session taskWithURL:url];
    XCTAssert([task isEqual:[task copy]]);
}

- (void)testCancelTask {
    NSString *urlString = @"http://httpbin.org/get";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    YMDataTask *d = [[YMDataTask alloc] initWithExpectation:[self expectationWithDescription:@"GET testCancelTask: task cancelation"]];
    d.cancelExpectation = [self expectationWithDescription:@"GET testCancelTask: task canceled"];
    [d runWithRequest:request];
    [d cancel];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (d.error) {
        XCTAssertEqual(d.task.error.code, NSURLErrorCancelled);
    } else {
        XCTFail();
    }
}

@end
