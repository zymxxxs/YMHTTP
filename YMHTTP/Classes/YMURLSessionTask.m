//
//  YMURLSessionTask.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import "YMURLSessionTask.h"
#import "YMURLSession.h"

@interface YMURLSessionTask ()

@property (nonatomic, strong) YMURLSession *session;
@property (nonatomic, strong) dispatch_queue_t workQueue;

@end

@implementation YMURLSessionTask

/// Create a data task. If there is a httpBody in the URLRequest, use that as a parameter
- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier {
    return [self initWithSession:session reqeust:request taskIdentifier:taskIdentifier body:nil];
}

- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier
                           body:(NSString *)body {
    self = [super init];
    if (self) {
        _session = session;
        _workQueue = dispatch_queue_create_with_target(
            "com.zymxxxs.URLSessionTask.WrokQueue", DISPATCH_QUEUE_SERIAL, session.workQueue);
        _taskIdentifier = taskIdentifier;
        _originalRequest = request;
        _currentRequest = request;
    }
    return self;
}

@end
