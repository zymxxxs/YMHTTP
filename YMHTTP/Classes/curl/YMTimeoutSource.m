//
//  YMTimeoutSource.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/1/2.
//
#import "YMTimeoutSource.h"

@implementation YMTimeoutSource

- (instancetype)initWithQueue:(dispatch_queue_t)queue
                 milliseconds:(NSInteger)milliseconds
                      handler:(dispatch_block_t)handler {
    self = [super init];
    if (self) {
        self.queue = queue;
        self.handler = handler;
        self.milliseconds = milliseconds;
        self.rawSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);

        uint64_t delay = MAX(1, milliseconds - 1);

        dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_MSEC);

        dispatch_source_set_timer(
            self.rawSource, start, delay * NSEC_PER_MSEC, self.milliseconds == 1 ? 1 * NSEC_PER_USEC : 1 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(self.rawSource, self.handler);
        dispatch_resume(self.rawSource);
    }
    return self;
}

- (void)dealloc {
    dispatch_source_cancel(self.rawSource);
}

@end
