//
//  YMHTTPUploadDelegate.h
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/6.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <YMHTTP/YMHTTP.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMHTTPUploadDelegate : XCTestCase <YMURLSessionDataDelegate>

@property (nonnull, nonatomic, strong) XCTestExpectation *uploadCompletedExpectation;
@property (nonnull, nonatomic, strong) NSInputStream *streamToProvideOnRequest;
@property int64_t totalBytesSent;

@end

NS_ASSUME_NONNULL_END
