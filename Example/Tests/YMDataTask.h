//
//  YMDataTask.h
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YMHTTP/YMHTTP.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMDataTask : NSObject

@property (copy) NSDictionary *result;
@property (copy) NSDictionary *args;
@property (strong) XCTestExpectation *responseReceivedExpectation;
@property (strong) XCTestExpectation *cancelExpectation;
@property (copy) YMURLSessionTask *task;
@property  BOOL error;

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation;

- (void)runWithRequest:(NSURLRequest *)request;

- (void)runWithURL:(NSURL *)URL;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
