//
//  NSArray+YMCategory.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/28.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (YMCategory)

- (NSArray *)ym_map:(id (^)(id object))block;
- (NSArray *)ym_filter:(BOOL (^)(id object))block;

@end

NS_ASSUME_NONNULL_END
