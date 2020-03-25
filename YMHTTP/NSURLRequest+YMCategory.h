//
//  NSURLRequest+YMCategory.h
//  Pods
//
//  Created by zymxxxs on 2020/3/4.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest (YMCategory) <NSCopying, NSMutableCopying>

- (instancetype)initWithURL:(NSURL *)URL connectToHost:(NSString *)connectToHost;
- (instancetype)initWithURL:(NSURL *)URL connectToHost:(NSString *)connectToHost connectToPort:(NSInteger)connectToPort;
- (instancetype)initWithURL:(NSURL *)URL
              connectToHost:(NSString *)connectToHost
              connectToPort:(NSInteger)connectToPort
                cachePolicy:(NSURLRequestCachePolicy)cachePolicy
            timeoutInterval:(NSTimeInterval)timeoutInterval;

@property (nullable, readonly, copy) NSString *ym_connectToHost;
@property (readonly) NSInteger ym_connectToPort;

@end

@interface NSMutableURLRequest (YMCategory)

@property (nullable, copy) NSString *ym_connectToHost;
@property NSInteger ym_connectToPort;

@end

NS_ASSUME_NONNULL_END
