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

@interface YMSessionDelegate : NSObject <YMURLSessionDelegate>

@property (nonnull, atomic, strong) XCTestExpectation *invalidateExpectation;

@end

NS_ASSUME_NONNULL_END
