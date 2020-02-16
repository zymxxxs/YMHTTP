//
//  NSInputStream+YMCategory.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/16.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSInputStream (YMCategory)


- (BOOL)ym_seekToPosition:(uint64_t)position;


@end

NS_ASSUME_NONNULL_END
