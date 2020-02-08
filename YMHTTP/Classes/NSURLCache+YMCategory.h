//
//  NSCachedURLResponse+YMCategory.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/7.
//

#import <Foundation/Foundation.h>

@class YMURLSessionTask;

NS_ASSUME_NONNULL_BEGIN

@interface NSURLCache (YMCategory)

- (void)ym_storeCachedResponse:(NSCachedURLResponse *)cachedResponse forDataTask:(YMURLSessionTask *)dataTask;
- (void)ym_getCachedResponseForDataTask:(YMURLSessionTask *)dataTask
                      completionHandler:(void (^)(NSCachedURLResponse *_Nullable cachedResponse))completionHandler;
- (void)ym_removeCachedResponseForDataTask:(YMURLSessionTask *)dataTask;

@end

NS_ASSUME_NONNULL_END
