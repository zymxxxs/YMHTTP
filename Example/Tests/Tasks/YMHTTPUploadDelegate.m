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

- (void)YMURLSession:(YMURLSession *)session
                 task:(YMURLSessionTask *)task
    needNewBodyStream:(void (^)(NSInputStream *_Nullable))completionHandler {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    if (!self.streamToProvideOnRequest) {
        XCTFail(@"This shouldn't have been invoked -- no stream was set.");
    }
    completionHandler(self.streamToProvideOnRequest);
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    [self.callbacks addObject:NSStringFromSelector(_cmd)];
    XCTAssertEqual(self.totalBytesSent, 1 * 512);
    [self.uploadCompletedExpectation fulfill];
}

@end
