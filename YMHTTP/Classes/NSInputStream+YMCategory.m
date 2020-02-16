//
//  NSInputStream+YMCategory.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/16.
//

#import "NSInputStream+YMCategory.h"

@implementation NSInputStream (YMCategory)

- (BOOL)ym_seekToPosition:(uint64_t)position {
    if (position <= 0) return false;
    
    if (position >= INT_MAX) return false;
    
    NSUInteger bufferSize = 1024;
    uint8_t buffer[1024];
    NSUInteger remainingBytes = position;
    
    if (self.streamStatus == NSStreamStatusNotOpen) {
        [self open];
    }
    
    while (remainingBytes > 0 && [self hasBytesAvailable]) {
        NSInteger read = [self read:buffer maxLength:MIN(bufferSize, remainingBytes)];
        if (read == -1) return false;
        remainingBytes -= remainingBytes;
    }

    if (remainingBytes !=0 ) return false;

    return true;
}

@end
