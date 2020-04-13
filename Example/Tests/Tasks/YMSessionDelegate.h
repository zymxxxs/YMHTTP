//
//  YMSessionDelegate.h
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <YMHTTP/YMHTTP.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMSessionDelegate : NSObject <YMURLSessionDelegate, YMURLSessionDataDelegate>

@property (nonnull, atomic, strong) XCTestExpectation *invalidateExpectation;
@property (nonnull, atomic, strong) XCTestExpectation *cancelExpectation;
@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, strong) YMURLSession *session;
@property (nonatomic, strong) YMURLSessionTask *task;
@property (nonnull, nonatomic, strong) void (^redirectionHandler)
    (NSHTTPURLResponse *response, NSURLRequest *request, void (^completionHandler)(NSURLRequest *_Nullable));
@property (nonnull, nonatomic, strong) void (^newBodyStreamHandler)(void (^)(NSInputStream *_Nullable));
@property (nonnull, nonatomic, strong) NSMutableData *receivedData;
@property (nonnull, nonatomic, strong) NSError *error;
@property (nonnull, nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSHTTPURLResponse *redirectionResponse;
@property (nonnull, nonatomic, strong) NSMutableArray<NSString *> *callbacks;
@property (nonatomic) int64_t totalBytesSent;
;

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation;

- (void)runWithRequest:(NSURLRequest *)request;
- (void)runUploadTask:(NSURLRequest *)request;

- (void)runWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
