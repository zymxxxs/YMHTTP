//
//  YMTimeoutSource.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/1/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMTimeoutSource : NSObject

@property (nonatomic, strong) dispatch_source_t rawSource;
@property (nonatomic, assign) NSInteger milliseconds;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_block_t handler;

- (instancetype)initWithQueue:(dispatch_queue_t)queue
                 milliseconds:(NSInteger)milliseconds
                      handler:(dispatch_block_t)handler;

@end

NS_ASSUME_NONNULL_END
