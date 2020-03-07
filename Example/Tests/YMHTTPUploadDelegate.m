//
//  YMHTTPUploadDelegate.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/6.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMHTTPUploadDelegate.h"

@implementation YMHTTPUploadDelegate

- (void)YMURLSession:(YMURLSession *)session
                        task:(YMURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    self.totalBytesSent = totalBytesSent;
}

- (void)YMURLSession:(YMURLSession *)session
                 task:(YMURLSessionTask *)task
    needNewBodyStream:(void (^)(NSInputStream *_Nullable))completionHandler {
    if (!self.streamToProvideOnRequest) {
        XCTFail(@"This shouldn't have been invoked -- no stream was set.");
    }
    completionHandler(self.streamToProvideOnRequest);
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    XCTAssertEqual(self.totalBytesSent, 1 * 1024);
    [self.uploadCompletedExpectation fulfill];
}

@end
