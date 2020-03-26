//
//  YMHTTPRedirectionDataTask.h
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/6.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <YMHTTP/YMHTTP.h>
#import "YMDataTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface YMHTTPRedirectionDataTask : YMDataTask

@property (nonnull, nonatomic, strong) NSMutableArray *callbacks;
@property (nonnull, nonatomic, strong) NSHTTPURLResponse *redirectionResponse;
@property (nonnull, nonatomic, strong) NSHTTPURLResponse *response;
@property (nonnull, nonatomic, strong) NSError *httpError;

@end

NS_ASSUME_NONNULL_END
