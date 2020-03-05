//
//  YMDownloadTask.h
//  YMHTTP_Example
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YMHTTP/YMHTTP.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMDownloadTask : XCTestCase<YMURLSessionDownloadDelegate>

@property (atomic, strong) NSURL *location;
@property (atomic, strong) XCTestExpectation *didDownloadExpectation;
@property (atomic, strong) XCTestExpectation *didCompleteExpectation;
@property (atomic, copy) YMURLSessionTask *task;
@property (atomic, copy) NSString *expectationsDescription;
@property (nullable, atomic, strong) XCTestCase *testCase;
@property int64_t totalBytesWritten;
@property (atomic, copy) void (^errorExpectation)(NSError *error);

- (instancetype)initWithTestCase:(XCTestCase *)textCase description:(NSString *)description;

- (void)makeDownloadExpectation;


- (void)runWithRequest:(NSURLRequest *)request;

- (void)runWithURL:(NSURL *)URL;

- (void)runWithTask:(YMURLSessionTask *)task errorExpectation:(void (^)(void))errorExpectation;

@end

NS_ASSUME_NONNULL_END
