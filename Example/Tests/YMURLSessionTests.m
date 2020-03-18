//
//  YMURLSessionTests.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <YMHTTP/YMHTTP.h>
#import "YMDataTask.h"
#import "YMDownloadTask.h"
#import "YMHTTPRedirectionDataTask.h"
#import "YMHTTPUploadDelegate.h"
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
        XCTAssertEqualObjects(
            d.args[@"capital"], @"testDataTaskWithURL", @"test_dataTaskWithURLRequest returned an unexpected result");
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
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET dataTaskWithURLCompletionHandlerWithSession: with a completion handler"];
    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                XCTAssertNil(error);
                XCTAssertNotNil(response);
                XCTAssertNotNil(data);
                if (![response isKindOfClass:[NSHTTPURLResponse class]]) return;
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                XCTAssertEqual(httpResponse.statusCode, 200, "HTTP response code is not 200");

                NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:NSJSONReadingMutableContainers
                                                                        error:nil];
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
        XCTAssertEqualObjects(d.args[@"capital"],
                              @"testDataTaskWithRequest",
                              @"test_dataTaskWithURLRequest returned an unexpected result");
    }
}

- (void)testDataTaskWithURLRequestCompletionHandler {
    NSString *urlString = @"http://httpbin.org/get?capital=testDataTaskWithURLRequestCompletionHandler";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testDataTaskWithURLRequestCompletionHandler: with a completion handler"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                XCTAssertNil(error);
                XCTAssertNotNil(response);
                XCTAssertNotNil(data);
                if (![response isKindOfClass:[NSHTTPURLResponse class]]) return;
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                XCTAssertEqual(httpResponse.statusCode, 200, "HTTP response code is not 200");

                NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:NSJSONReadingMutableContainers
                                                                        error:nil];
                NSDictionary *args = value[@"args"] ?: @{};
                XCTAssertEqualObjects(
                    args[@"capital"], @"testDataTaskWithURLRequestCompletionHandler", "Did not receive expected value");
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

    XCTestExpectation *te =
        [self expectationWithDescription:@"POST testDataTaskWithHttpInputStream: with HTTP Body as InputStream"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config];
    YMURLSessionTask *task =
        [session taskWithRequest:request
               completionHandler:^(
                   NSData *_Nullable responseData, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                   XCTAssertNil(error);
                   XCTAssertNotNil(response);
                   XCTAssertNotNil(data);
                   if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
                       XCTFail("response is invalid");
                       return;
                   }

                   NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                   XCTAssertEqual(httpResponse.statusCode, 200, @"HTTP response code is not 200");

                   NSDictionary *value = [NSJSONSerialization JSONObjectWithData:responseData
                                                                         options:NSJSONReadingMutableContainers
                                                                           error:nil];
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
    YMDownloadTask *d =
        [[YMDownloadTask alloc] initWithTestCase:self
                                     description:@"Download GET testDownloadTaskWithURL: with a delegate"];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testDownloadTaskWithRequest {
    NSString *urlString = @"http://httpbin.org/image/jepg";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    YMDownloadTask *d =
        [[YMDownloadTask alloc] initWithTestCase:self
                                     description:@"Download GET testDownloadTaskWithRequest: with a delegate"];
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
    XCTestExpectation *te =
        [self expectationWithDescription:
                  @"Download GET downloadTaskWithRequestAndHandlerWithSession: with a completion handler"];
    NSString *urlString = @"http://httpbin.org/image/svg";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    YMURLSessionTask *task =
        [session taskWithDownloadRequest:request
                       completionHandler:^(
                           NSURL *_Nullable location, NSURLResponse *_Nullable response, NSError *_Nullable error) {
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
    XCTestExpectation *te =
        [self expectationWithDescription:@"Download GET testDownloadTaskWithURLAndHandler: with a completion handler"];
    NSString *urlString = @"http://httpbin.org/image/webp";
    NSURL *url = [NSURL URLWithString:urlString];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    YMURLSessionTask *task = [session
        taskWithDownloadURL:url
          completionHandler:^(NSURL *_Nullable location, NSURLResponse *_Nullable response, NSError *_Nullable error) {
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
    YMDownloadTask *d =
        [[YMDownloadTask alloc] initWithTestCase:self
                                     description:@"Download GET testGzippedDownloadTask: with a delegate"];
    [d runWithRequest:request];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testFinishTasksAndInvalidate {
    XCTestExpectation *invalidateExpectation = [self expectationWithDescription:@"Session invalidation"];
    XCTestExpectation *completionExpectation = [self
        expectationWithDescription:@"GET testFinishTasksAndInvalidate: task completion before session invalidation"];

    NSString *urlString = @"http://httpbin.org/get";
    NSURL *url = [NSURL URLWithString:urlString];
    YMSessionDelegate *delegate = [YMSessionDelegate new];
    delegate.invalidateExpectation = invalidateExpectation;
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
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
    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                XCTAssertNotNil(error);
                XCTAssertEqual(error.code, NSURLErrorBadURL);
                [completionExpectation fulfill];
            }];
    [task resume];

    [self waitForExpectationsWithTimeout:5
                                 handler:^(NSError *_Nullable error) {
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

    YMDataTask *d = [[YMDataTask alloc]
        initWithExpectation:[self expectationWithDescription:@"GET testCancelTask: task cancelation"]];
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

- (void)testVerifyRequestHeaders {
    XCTestExpectation *te = [self expectationWithDescription:@"POST testVerifyRequestHeaders: get request headers"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"http://httpbin.org/post";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.allHTTPHeaderFields = @{@"header1" : @"value1"};

    YMURLSessionTask *task = [session
          taskWithRequest:request
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNil(error);
            NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data
                                                                  options:NSJSONReadingMutableContainers
                                                                    error:nil];
            XCTAssertNotNil(value[@"headers"][@"Header1"]);
            [te fulfill];
        }];
    [task resume];
    request.allHTTPHeaderFields = nil;
    [self waitForExpectationsWithTimeout:30 handler:nil];
}

- (void)testVerifyHttpAdditionalHeaders {
    XCTestExpectation *te =
        [self expectationWithDescription:@"POST testVerifyHttpAdditionalHeaders with additional headers"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;
    config.HTTPAdditionalHeaders = @{
        @"header2" : @"svalue2",
        @"header3" : @"svalue3",
        @"header4" : @"svalue4",
    };
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"http://httpbin.org/post";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.allHTTPHeaderFields = @{
        @"HEAder2" : @"rvalue2",
        @"HeAder1" : @"rvalue1",
        @"Header4" : @"rvalue4",
    };

    YMURLSessionTask *task = [session
          taskWithRequest:request
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNil(error);
            NSDictionary *value = [NSJSONSerialization JSONObjectWithData:data
                                                                  options:NSJSONReadingMutableContainers
                                                                    error:nil];
            NSDictionary *headers = value[@"headers"];
            XCTAssertEqualObjects(headers[@"Header1"], @"rvalue1");
            XCTAssertEqualObjects(headers[@"Header2"], @"rvalue2");
            XCTAssertEqualObjects(headers[@"Header3"], @"svalue3");
            XCTAssertEqualObjects(headers[@"Header4"], @"rvalue4");
            [te fulfill];
        }];
    [task resume];
    request.allHTTPHeaderFields = nil;
    [self waitForExpectationsWithTimeout:30 handler:nil];
}

- (void)testTaskTimeOut {
    XCTestExpectation *te = [self expectationWithDescription:@"GET testTaskTimeOut: will timeout"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"http://httpbin.org/delay/10";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5;

    YMURLSessionTask *task = [session
          taskWithRequest:request
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(error);
            XCTAssertEqual(error.code, NSURLErrorTimedOut);
            [te fulfill];
        }];
    [task resume];
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testConcurrentRequests {
    NSMutableArray *dataTasks = @[].mutableCopy;
    dispatch_queue_t syncQ = dispatch_queue_create("TEST_DATATASKWITHURL_SYNC_Q", NULL);
    dispatch_group_t gourp = dispatch_group_create();
    for (int i = 0; i < 10; i++) {
        dispatch_group_enter(gourp);
        NSString *urlString = [NSString stringWithFormat:@"http://httpbin.org/get?capital=testDataTaskWithURL%@", @(i)];
        NSURL *url = [NSURL URLWithString:urlString];
        XCTestExpectation *te = [self
            expectationWithDescription:[NSString
                                           stringWithFormat:@"GET testConcurrentRequests %@: with a delegate", @(i)]];
        YMDataTask *d = [[YMDataTask alloc] initWithExpectation:te];
        [d runWithURL:url];
        dispatch_async(syncQ, ^{
            [dataTasks addObject:d];
            dispatch_group_leave(gourp);
        });
    }
    [self waitForExpectationsWithTimeout:12 handler:nil];
    dispatch_group_wait(gourp, DISPATCH_TIME_FOREVER);
}

- (void)testHttpRedirectionWithCompleteRelativePath {
    NSString *urlString = @"http://httpbin.org/redirect-to?url=http%3A%2F%2Fhttpbin.org%2Fget";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testHttpRedirectionWithCompleteRelativePath: with HTTP redirection"];
    YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertEqualObjects(d.result[@"url"],
                              @"http://httpbin.org/get",
                              @"testHttpRedirectionWithCompleteRelativePath returned an unexpected result");
    }
}

- (void)testHttpRedirectionWithInCompleteRelativePath {
    NSString *urlString = @"http://httpbin.org/redirect-to?url=%2Fget";
    NSURL *url = [NSURL URLWithString:urlString];
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testHttpRedirectionWithInCompleteRelativePath: with HTTP redirection"];
    YMHTTPRedirectionDataTask *d = [[YMHTTPRedirectionDataTask alloc] initWithExpectation:te];
    [d runWithURL:url];
    [self waitForExpectationsWithTimeout:12 handler:nil];
    if (!d.error) {
        XCTAssertEqualObjects(d.result[@"url"],
                              @"http://httpbin.org/get",
                              @"testHttpRedirectionWithCompleteRelativePath returned an unexpected result");
    }
}

- (void)testHttpRedirectionTimeout {
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testHttpRedirectionTimeout: timeout with redirection"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"http://httpbin.org/redirect-to?url=%2Fdelay%2F10";
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

- (void)testOutOfRangeButCorrectlyFormattedHTTPCode {
    XCTestExpectation *te =
        [self expectationWithDescription:@"GET testOutOfRangeButCorrectlyFormattedHTTPCode: out of range HTTP code"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"http://httpbin.org/status/999";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];

    YMURLSessionTask *task = [session
          taskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNotNil(response);
            XCTAssertNil(error);
            NSHTTPURLResponse *httpresponse = (NSHTTPURLResponse *)response;
            XCTAssertEqual(httpresponse.statusCode, 999, @"Unexpected error code");
            [te fulfill];
        }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testMissingContentLengthButStillABody {
    XCTestExpectation *te = [self expectationWithDescription:@"GET testMissingContentLengthButStillABody"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"https://httpbin.org/stream-bytes/10";
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];

    YMURLSessionTask *task = [session
          taskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNotNil(response);
            XCTAssertNil(error);
            NSHTTPURLResponse *httpresponse = (NSHTTPURLResponse *)response;
            XCTAssertEqual(httpresponse.statusCode, 200, @"HTTP response code is not 200");
            [te fulfill];
        }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testSimpleUploadWithDelegate {
    YMHTTPUploadDelegate *delegate = [[YMHTTPUploadDelegate alloc] init];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];

    delegate.uploadCompletedExpectation = [self expectationWithDescription:@"PUT testSimpleUploadWithDelegate"];

    NSString *urlString = @"https://httpbin.org/put";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"PUT";

    NSData *data = [[NSData alloc] initWithBytes:"123" length:512 * 1];
    YMURLSessionTask *task = [session taskWithRequest:req fromData:data];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testRequestWithEmptyBody {
    NSArray *httpMethods = @[ @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = [NSString stringWithFormat:@"https://httpbin.org/%@", [method lowercaseString]];
        YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
        YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = method;

        XCTestExpectation *e =
            [self expectationWithDescription:[NSString stringWithFormat:@"%@ testRequestWithEmptyBody", method]];

        YMURLSessionTask *task = [session
              taskWithRequest:request
            completionHandler:^(
                NSData *_Nullable data, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
                XCTAssertNil(error);
                XCTAssertEqual(response.statusCode, 200);

                NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                XCTAssertEqualObjects(jsonBody[@"url"], urlString);
                if ([method isEqualToString:@"GET"]) {
                    XCTAssertNil(jsonBody[@"headers"][@"Content-Length"], @"Unexpected Content-Length for get request");
                } else {
                    XCTAssertEqualObjects(jsonBody[@"headers"][@"Content-Length"], @"0");
                }
                [e fulfill];
            }];
        [task resume];
        [self waitForExpectationsWithTimeout:10 handler:nil];
    }
}

- (void)testRequestWithNonEmptyBody {
    NSArray *httpMethods = @[ @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        NSString *urlString = [NSString stringWithFormat:@"https://httpbin.org/%@", [method lowercaseString]];
        YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
        YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.HTTPMethod = method;
        request.HTTPBody = [@"this is a request body data" dataUsingEncoding:NSUTF8StringEncoding];

        XCTestExpectation *e =
            [self expectationWithDescription:[NSString stringWithFormat:@"%@ testRequestWithNonEmptyBody", method]];

        YMURLSessionTask *task =
            [session taskWithRequest:request
                   completionHandler:^(
                       NSData *_Nullable data, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
                       if ([method isEqualToString:@"GET"]) {
                           XCTAssertNotNil(error);
                           XCTAssertNil(response);
                           XCTAssertNil(data);
                       } else {
                           XCTAssertEqual(response.statusCode, 200);
                           NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                           XCTAssertEqualObjects(jsonBody[@"url"], urlString);
                           XCTAssertEqualObjects(jsonBody[@"headers"][@"Content-Length"],
                                                 @(request.HTTPBody.length).stringValue);
                       }
                       [e fulfill];
                   }];
        [task resume];
        [self waitForExpectationsWithTimeout:10 handler:nil];
    }
}

- (void)testSimpleUploadWithDelegateProvidingInputStream {
    NSArray *httpMethods = @[ @"GET", @"PUT", @"POST", @"DELETE" ];
    for (NSString *method in httpMethods) {
        YMHTTPUploadDelegate *delegate = [[YMHTTPUploadDelegate alloc] init];
        YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 8;
        YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
        XCTestExpectation *expect = [self
            expectationWithDescription:[NSString
                                           stringWithFormat:@"%@ testSimpleUploadWithDelegateProvidingInputStream",
                                                            method]];
        if ([method isEqualToString:@"GET"] || [method isEqualToString:@"HEAD"]) {
            [expect setInverted:true];
        }
        delegate.uploadCompletedExpectation = expect;

        NSString *urlString = @"http://httpbin.org/put";
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = method;

        NSData *data = [[NSData alloc] initWithBytes:"123" length:512 * 1];
        NSInputStream *stream = [[NSInputStream alloc] initWithData:data];
        delegate.streamToProvideOnRequest = stream;
        YMURLSessionTask *task = [session taskWithStreamedRequest:req];
        [task resume];
        [self waitForExpectationsWithTimeout:10 handler:nil];

        if ([method isEqualToString:@"GET"] || [method isEqualToString:@"HEAD"]) {
            XCTAssertEqual(delegate.callbacks.count, 1, @"Callback count for GET request");
            XCTAssertEqualObjects(delegate.callbacks[0], @"YMURLSession:task:needNewBodyStream:");
        } else {
            XCTAssertEqual(delegate.callbacks.count, 3, @"Callback count for \(method) request");
            XCTAssertEqualObjects(delegate.callbacks[0], @"YMURLSession:task:needNewBodyStream:");
            XCTAssertEqualObjects(delegate.callbacks[2], @"YMURLSession:task:didReceiveData:");
            XCTAssertEqualObjects(delegate.callbacks[1],
                                  @"YMURLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:");
        }
    }
}

- (void)emptyCookieStorage:(NSHTTPCookieStorage *)cookieStorage {
    if (cookieStorage && cookieStorage.cookies) {
        for (NSHTTPCookie *cookie in cookieStorage.cookies) {
            [cookieStorage deleteCookie:cookie];
        }
    }
}

- (void)testDisableCookiesStorage {
    XCTestExpectation *expect = [self expectationWithDescription:@"test testDisableCookiesStorage"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;

    [self emptyCookieStorage:config.HTTPCookieStorage];
    XCTAssertEqual(config.HTTPCookieStorage.cookies.count, 0);

    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    NSString *urlString =
        @"https://httpbin.org/response-headers?Set-Cookie=a=bbbb&Set-Cookie=a=bbbb1&Set-Cookie=b=bbbb2";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";

    YMURLSessionTask *task = [session
          taskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNil(error);
            NSHTTPURLResponse *httpresponse = (NSHTTPURLResponse *)response;
            XCTAssertNotNil(httpresponse.allHeaderFields[@"Set-Cookie"]);
            [expect fulfill];
        }];
    [task resume];
    [self waitForExpectationsWithTimeout:30 handler:nil];
    XCTAssertEqual([NSHTTPCookieStorage sharedHTTPCookieStorage].cookies.count, 0);
}

- (void)testCookiesStorage {
    XCTestExpectation *expect = [self expectationWithDescription:@"test testCookiesStorage"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;

    [self emptyCookieStorage:config.HTTPCookieStorage];
    XCTAssertEqual(config.HTTPCookieStorage.cookies.count, 0);

    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    NSString *urlString =
        @"https://httpbin.org/"
        @"response-headers?Set-Cookie=a=bbbb&Set-Cookie=a=bbbb1&Set-Cookie=b=bbbb2&Set-Cookie=b=bbbb2";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";

    YMURLSessionTask *task = [session
          taskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNil(error);
            NSHTTPURLResponse *httpresponse = (NSHTTPURLResponse *)response;
            XCTAssertNotNil(httpresponse.allHeaderFields[@"Set-Cookie"]);
            [expect fulfill];
        }];
    [task resume];
    [self waitForExpectationsWithTimeout:30 handler:nil];
    XCTAssertEqual([NSHTTPCookieStorage sharedHTTPCookieStorage].cookies.count, 2);
}

- (void)testPreviouslySetCookiesAreSentInLaterRequests {
    XCTestExpectation *expect1 =
        [self expectationWithDescription:@"test1 testPreviouslySetCookiesAreSentInLaterRequests"];
    XCTestExpectation *expect2 =
        [self expectationWithDescription:@"test2 testPreviouslySetCookiesAreSentInLaterRequests"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;

    [self emptyCookieStorage:config.HTTPCookieStorage];
    XCTAssertEqual(config.HTTPCookieStorage.cookies.count, 0);

    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    NSString *urlString =
        @"https://httpbin.org/"
        @"response-headers?Set-Cookie=a=bbbb&Set-Cookie=a=bbbb1&Set-Cookie=b=bbbb2&Set-Cookie=b=bbbb2";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    __block YMURLSessionTask *task2 = nil;

    YMURLSessionTask *task1 = [session
          taskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNotNil(data);
            XCTAssertNil(error);
            NSHTTPURLResponse *httpresponse = (NSHTTPURLResponse *)response;
            XCTAssertNotNil(httpresponse.allHeaderFields[@"Set-Cookie"]);
            XCTAssertEqual([NSHTTPCookieStorage sharedHTTPCookieStorage].cookies.count, 2);

            task2 = [session taskWithURL:[NSURL URLWithString:@"https://httpbin.org/cookies"]
                       completionHandler:^(
                           NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                           XCTAssertNotNil(data);
                           XCTAssertNil(error);
                           NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                                  options:NSJSONReadingMutableContainers
                                                                                    error:nil];
                           XCTAssertNotNil(result[@"cookies"]);
                           NSDictionary *cookies = @{@"a" : @"bbbb1", @"b" : @"bbbb2"};
                           XCTAssertEqualObjects(result[@"cookies"], cookies);
                           [expect2 fulfill];
                       }];
            [task2 resume];
            [expect1 fulfill];
        }];
    [task1 resume];
    [self waitForExpectationsWithTimeout:100 handler:nil];
    XCTAssertEqual([NSHTTPCookieStorage sharedHTTPCookieStorage].cookies.count, 2);
}

//- (void)testBasicAuthRequest {
//    NSString *urlString = @"https://httpbin.org/basic-auth/zymxxxs/zymxxxs";
//    NSURL *url = [NSURL URLWithString:urlString];
//    XCTestExpectation *te = [self expectationWithDescription:@"GET testBasicAuthRequest: with a delegate"];
//    YMDataTask *d = [[YMDataTask alloc] initWithExpectation:te];
//    [d runWithURL:url];
//    [self waitForExpectationsWithTimeout:12 handler:nil];
//}

- (void)testBasicAuthWithUnauthorizedHeader {
}

- (void)testPostWithEmptyBody {
    XCTestExpectation *te = [self expectationWithDescription:@"POST testPostWithEmptyBody: post with empty body"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 5;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];

    NSString *urlString = @"https://httpbin.org/post";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";

    YMURLSessionTask *task = [session
          taskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            XCTAssertNil(error);
            if (![response isKindOfClass:[NSHTTPURLResponse class]]) return;
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            XCTAssertEqual(httpResponse.statusCode, 200, "HTTP response code is not 200");
            [te fulfill];
        }];
    [task resume];
    [self waitForExpectationsWithTimeout:12 handler:nil];
}

- (void)testCheckErrorTypeAfterInvalidateAndCancel {
    XCTestExpectation *expectation =
        [self expectationWithDescription:@"Check error code of tasks after invalidateAndCancel"];

    NSString *urlString = @"http://httpbin.org/delay/5";
    NSURL *url = [NSURL URLWithString:urlString];
    YMSessionDelegate *delegate = [YMSessionDelegate new];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                XCTAssertNotNil(error);
                XCTAssertEqual(error.code, NSURLErrorCancelled);
                [expectation fulfill];
            }];
    [task resume];
    [session invalidateAndCancel];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testTaskCountAfterInvalidateAndCancel {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Check task count after invalidateAndCancel"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    NSURL *url1 = [NSURL URLWithString:@"http://httpbin.org/delay/5"];
    NSURL *url2 = [NSURL URLWithString:@"http://httpbin.org/delay/15"];
    NSURL *url3 = [NSURL URLWithString:@"http://httpbin.org/delay/25"];

    YMURLSessionTask *task1 = [session taskWithURL:url1];
    YMURLSessionTask *task2 = [session taskWithURL:url2];
    YMURLSessionTask *task3 = [session taskWithURL:url3];

    [task1 resume];
    [task2 resume];
    [session invalidateAndCancel];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [session getAllTasksWithCompletionHandler:^(NSArray<__kindof YMURLSessionTask *> *_Nonnull tasksBeforeResume) {
            XCTAssertEqual(tasksBeforeResume.count, 0);

            [task3 resume];
            [session
                getAllTasksWithCompletionHandler:^(NSArray<__kindof YMURLSessionTask *> *_Nonnull tasksAfterResume) {
                    XCTAssertEqual(tasksAfterResume.count, 0);
                    [expectation fulfill];
                }];
        }];
    });
    [self waitForExpectationsWithTimeout:8 handler:nil];
}

- (void)testSessionDelegateAfterInvalidateAndCancel {
    YMSessionDelegate *delegate = [YMSessionDelegate new];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    [session invalidateAndCancel];
    [NSThread sleepForTimeInterval:5];
    XCTAssertNil(session.delegate);
}

- (void)testGetAllTasks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Tasks URLSession.getAllTasks"];

    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    NSURL *url1 = [NSURL URLWithString:@"https://httpbin.org/delay/5"];
    NSURL *url2 = [NSURL URLWithString:@"https://httpbin.org/delay/10"];
    NSURL *url3 = [NSURL URLWithString:@"https://httpbin.org/delay/15"];

    YMURLSessionTask *task1 = [session taskWithURL:url1];
    YMURLSessionTask *task2 = [session taskWithURL:url2];
    YMURLSessionTask *task3 = [session taskWithURL:url3];

    [session getAllTasksWithCompletionHandler:^(NSArray<__kindof YMURLSessionTask *> *_Nonnull tasksBeforeResume) {
        XCTAssertEqual(tasksBeforeResume.count, 0);

        [task1 cancel];

        [task2 resume];
        [task2 suspend];

        [task3 suspend];

        [session getAllTasksWithCompletionHandler:^(NSArray<__kindof YMURLSessionTask *> *_Nonnull tasksAfterCancel) {
            XCTAssertEqual(tasksAfterCancel.count, 1);

            [task3 resume];
            [session getAllTasksWithCompletionHandler:^(
                         NSArray<__kindof YMURLSessionTask *> *_Nonnull tasksAfterFirstResume) {
                XCTAssertEqual(tasksAfterFirstResume.count, 1);

                [task3 resume];
                [session getAllTasksWithCompletionHandler:^(
                             NSArray<__kindof YMURLSessionTask *> *_Nonnull tasksAfterSecondResume) {
                    XCTAssertEqual(tasksAfterSecondResume.count, 2);
                    [expectation fulfill];
                }];
            }];
        }];
    }];
    [self waitForExpectationsWithTimeout:16 handler:nil];
}

- (void)testNoDoubleCallbackWhenCancellingAndProtocolFailsFast {
    XCTestExpectation *callback1 = [self expectationWithDescription:@"Callback call #1"];
    XCTestExpectation *callback2 = [self expectationWithDescription:@"Callback call #2"];
    __block int callbackCount = 0;
    [callback2 setInverted:YES];

    NSString *urlString = @"ftp://httpbin.org/get";
    NSURL *url = [NSURL URLWithString:urlString];
    YMSessionDelegate *delegate = [YMSessionDelegate new];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];

    YMURLSessionTask *task =
        [session taskWithURL:url
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                callbackCount += 1;
                XCTAssertNotNil(error);
                XCTAssertNotEqual(error.code, NSURLErrorCancelled);
                XCTAssertEqual(error.code, NSURLErrorUnsupportedURL);
                if (callbackCount == 1) {
                    [callback1 fulfill];
                } else {
                    [callback2 fulfill];
                }
            }];
    [task resume];
    [session invalidateAndCancel];
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testCancelledTasksCannotBeResumed {
    NSString *urlString = @"http://httpbin.org/delay/5";
    NSURL *url = [NSURL URLWithString:urlString];
    YMSessionDelegate *delegate = [YMSessionDelegate new];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithURL:url];
    [task cancel];
    [task resume];

    XCTestExpectation *expectation = [self expectationWithDescription:@"getAllTasks callback called"];
    [session getAllTasksWithCompletionHandler:^(NSArray<__kindof YMURLSessionTask *> *_Nonnull tasks) {
        XCTAssertEqual(tasks.count, 0);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSuspendResumeTask {
    XCTestExpectation *expectation = [self expectationWithDescription:@"GET testSuspendResumeTask: suspend task"];
    YMURLSessionTask *task = [[YMURLSession sharedSession]
              taskWithURL:[NSURL URLWithString:@"https://httpbin.org/get"]
        completionHandler:^(NSData *_Nullable data, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            if (response.statusCode == 200) {
                [expectation fulfill];
            } else {
                XCTFail();
            }
        }];

    [task suspend];  // 2
    XCTAssertEqual(task.state, YMURLSessionTaskStateSuspended);
    [task suspend];  // 3
    XCTAssertEqual(task.state, YMURLSessionTaskStateSuspended);
    [task resume];  // 2
    XCTAssertEqual(task.state, YMURLSessionTaskStateSuspended);
    [task resume];  // 1
    XCTAssertEqual(task.state, YMURLSessionTaskStateSuspended);
    [task resume];  // 0
    XCTAssertEqual(task.state, YMURLSessionTaskStateRunning);
    [task resume];  // -1
    XCTAssertEqual(task.state, YMURLSessionTaskStateRunning);
    [task resume];  // -2
    XCTAssertEqual(task.state, YMURLSessionTaskStateRunning);

    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertEqual(task.state, YMURLSessionTaskStateCompleted);
}

@end
