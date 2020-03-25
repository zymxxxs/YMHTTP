//
//  YMDownloadTask.m
//  YMHTTP_Example
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMDownloadTask.h"

@implementation YMDownloadTask

- (instancetype)initWithTestCase:(XCTestCase *)testCase description:(NSString *)description {
    self = [super init];
    if (self) {
        self.expectationsDescription = description;
        self.testCase = testCase;
        self.didCompleteExpectation =
            [testCase expectationWithDescription:[NSString stringWithFormat:@"Did Complete %@", description]];
    }
    return self;
}

- (void)makeDownloadExpectation {
    if (self.didDownloadExpectation != nil) return;
    self.didDownloadExpectation = [self.testCase
        expectationWithDescription:[NSString stringWithFormat:@"Did finish download: %@", self.description]];
    self.testCase = nil;
}

- (void)runWithURL:(NSURL *)URL {
    [self makeDownloadExpectation];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithDownloadURL:URL];
    [task resume];
}

- (void)runWithRequest:(NSURLRequest *)request {
    [self makeDownloadExpectation];
    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 8;
    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    YMURLSessionTask *task = [session taskWithDownloadRequest:request];
    [task resume];
}

- (void)runWithTask:(YMURLSessionTask *)task errorExpectation:(void (^)(void))errorExpectation {
    //    YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
    //    config.timeoutIntervalForRequest = 8;
    //    YMURLSession *session = [YMURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
}

- (void)YMURLSession:(YMURLSession *)session
                 downloadTask:(YMURLSessionTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
    if (self.errorExpectation) {
        NSLog(@"download: %@", downloadTask);
        NSLog(@"at location: %@", location);
        XCTFail(@"Expected an error, but got …didFinishDownloadingTo… from download task");
    } else {
        NSError *e = nil;
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:location.path error:&e];
        if (e) {
            XCTFail(@"Unable to calculate size of the downloaded file");
        } else {
            XCTAssertEqual([attr[NSFileSize] integerValue],
                           self.totalBytesWritten,
                           @"Size of downloaded file not equal to total bytes downloaded");
        }
    }
    self.location = location;
    [self.didDownloadExpectation fulfill];
}

- (void)YMURLSession:(YMURLSession *)session
                 downloadTask:(YMURLSessionTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.totalBytesWritten = totalBytesWritten;
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (self.errorExpectation) {
        if (error) {
            self.errorExpectation(error);
        } else {
            XCTFail(@"Expected an error, but got a completion without error from download task %@", task);
        }
    } else {
        if (error) {
            XCTAssertEqual(error.code, -1001, @"Unexpected error code");
        }
    }
    [self.didCompleteExpectation fulfill];
}

@end
