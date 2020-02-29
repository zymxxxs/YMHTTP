//
//  YMURLCacheHelper.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMURLCacheHelper : NSObject

+ (BOOL)canCacheResponse:(NSCachedURLResponse *)response request:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
