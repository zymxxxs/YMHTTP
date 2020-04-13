//
//  YMHTTPUploadDelegate.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/6.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMHTTPUploadDelegate.h"

@implementation YMHTTPUploadDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        self.callbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)YMURLSession:(YMURLSession *)session
                        task:(YMURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    NSString *last = (NSString *)self.callbacks.lastObject;
    if (![last isEqualToString:NSStringFromSelector(_cmd)]) {
        [self.callbacks addObject:NSStringFromSelector(_cmd)];
    }
    self.totalBytesSent = totalBytesSent;
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    [self.uploadCompletedExpectation fulfill];
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
}

@end
