//
//  YMCacheDataTask.h
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/8.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMDataTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface YMCacheDataTask : YMDataTask

@property (nonatomic, assign) YMURLSessionResponseDisposition disposition;
@property (nonatomic, strong) NSHTTPURLResponse *response;

@end

NS_ASSUME_NONNULL_END
