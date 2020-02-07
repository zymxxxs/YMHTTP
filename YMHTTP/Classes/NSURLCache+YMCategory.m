//
//  NSCachedURLResponse+YMCategory.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/7.
//

#import "NSURLCache+YMCategory.h"
#import "YMURLSessionTask.h"


@implementation NSURLCache (YMCategory)

- (void)ym_removeCachedResponseForDataTask:(YMURLSessionTask *)dataTask {
    if (!dataTask.currentRequest) return;
    [self removeCachedResponseForRequest:dataTask.currentRequest];
}

- (void)ym_storeCachedResponse:(NSCachedURLResponse *)cachedResponse forDataTask:(YMURLSessionTask *)dataTask {
    if (!dataTask.currentRequest) return;
    [self storeCachedResponse:cachedResponse forRequest:dataTask.currentRequest];
}

- (void)ym_getCachedResponseForDataTask:(YMURLSessionTask *)dataTask completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    if (!dataTask.currentRequest) {
        completionHandler(nil);
        return;
    }
    dispatch_queue_t globalQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(globalQ, ^{
        completionHandler([self cachedResponseForRequest:dataTask.currentRequest]);
    });
}

@end
