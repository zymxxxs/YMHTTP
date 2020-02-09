//
//  YMURLSessionTask.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import "YMURLSessionTask.h"
#import "YMEasyHandle.h"
#import "YMMacro.h"
#import "YMTransferState.h"
#import "YMURLSession.h"
#import "YMURLSessionDelegate.h"
#import "YMURLSessionTaskBehaviour.h"
#import "YMURLSessionTaskBody.h"

typedef NS_ENUM(NSUInteger, YMURLSessionTaskInternalState) {
    /// Task has been created, but nothing has been done, yet
    YMURLSessionTaskInternalStateInitial,
    /// The task is being fulfilled from the cache rather than the network.
    YMURLSessionTaskInternalStateFulfillingFromCache,
    /// The easy handle has been fully configured. But it is not added to
    /// the multi handle.
    YMURLSessionTaskInternalStateTransferReady,
    /// The easy handle is currently added to the multi handle
    YMURLSessionTaskInternalStateTransferInProgress,
    /// The transfer completed.
    ///
    /// The easy handle has been removed from the multi handle. This does
    /// not necessarily mean the task completed. A task that gets
    /// redirected will do multiple transfers.
    YMURLSessionTaskInternalStateTransferCompleted,
    /// The transfer failed.
    ///
    /// Same as `.transferCompleted`, but without response / body data
    YMURLSessionTaskInternalStateTransferFailed,
    /// Waiting for the completion handler of the HTTP redirect callback.
    ///
    /// When we tell the delegate that we're about to perform an HTTP
    /// redirect, we need to wait for the delegate to let us know what
    /// action to take.
    YMURLSessionTaskInternalStateWaitingForRedirectHandler,
    /// Waiting for the completion handler of the 'did receive response' callback.
    ///
    /// When we tell the delegate that we received a response (i.e. when
    /// we received a complete header), we need to wait for the delegate to
    /// let us know what action to take. In this state the easy handle is
    /// paused in order to suspend delegate callbacks.
    YMURLSessionTaskInternalStateWaitingForResponseHandler,
    /// The task is completed
    ///
    /// Contrast this with `.transferCompleted`.
    YMURLSessionTaskInternalStateTaskCompleted,
};

@interface YMURLSessionTask () <YMEasyHandleDelegate>

@property (nonatomic, strong) YMURLSession *session;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, assign) NSUInteger suspendCount;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSURLRequest *authRequest;

@property (nonatomic, strong) YMEasyHandle *easyHandle;
@property (nonatomic, assign) YMURLSessionTaskInternalState internalState;
@property (nonatomic, strong) YMTransferState *transferState;
@property (nonatomic, strong) NSCachedURLResponse *cachedResponse;
@property (nonatomic, strong) YMURLSessionTaskBody *knownBody;

@end

@implementation YMURLSessionTask

/// Create a data task. If there is a httpBody in the URLRequest, use that as a parameter
- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier {
    if (request.HTTPBody) {
        YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithData:request.HTTPBody];
        return [self initWithSession:session reqeust:request taskIdentifier:taskIdentifier body:body];
    } else if (request.HTTPBodyStream) {
        YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithInputStream:request.HTTPBodyStream];
        return [self initWithSession:session reqeust:request taskIdentifier:taskIdentifier body:body];
    } else {
        YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] init];
        return [self initWithSession:session reqeust:request taskIdentifier:taskIdentifier body:body];
    }
}

- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier
                           body:(YMURLSessionTaskBody *)body {
    self = [super init];
    if (self) {
        [self setupProps];
        _session = session;
        _workQueue = dispatch_queue_create_with_target(
            "com.zymxxxs.URLSessionTask.WrokQueue", DISPATCH_QUEUE_SERIAL, session.workQueue);
        _taskIdentifier = taskIdentifier;
        _originalRequest = request;
        _knownBody = body;
        _currentRequest = request;
    }
    return self;
}

- (void)setupProps {
    _state = YMURLSessionTaskStateSuspended;
    _suspendCount = 1;
}

- (void)resume {
    dispatch_sync(_workQueue, ^{
        if (_state == YMURLSessionTaskStateCanceling || _state == YMURLSessionTaskStateCompleted) return;
        _suspendCount -= 1;
        if (_suspendCount > 0) {
            // TODO: throw Error
        }
        [self updateTaskState];
        if (_suspendCount == 0) {
            BOOL isHTTPScheme = [_originalRequest.URL.scheme isEqualToString:@"http"] ||
                                [_originalRequest.URL.scheme isEqualToString:@"https"];
            if (isHTTPScheme) {
                // TODO: lock protocol
                _easyHandle = [[YMEasyHandle alloc] initWithDelegate:self];
                _internalState = YMURLSessionTaskInternalStateInitial;
                dispatch_async(_workQueue, ^{
                    [self startLoading];
                });
            } else {
                if (_error == nil) {
                    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                    userInfo[NSLocalizedDescriptionKey] = @"unsupported URL";
                    NSURL *url = _originalRequest.URL;
                    if (url) {
                        userInfo[NSURLErrorFailingURLErrorKey] = url;
                        userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString;
                    }
                    NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain
                                                            code:NSURLErrorUnsupportedURL
                                                        userInfo:userInfo];
                    _error = urlError;
                }
            }
        }
    });
}

#pragma mark - Private Methods

- (void)updateTaskState {
    if (_suspendCount == 0) {
        _state = YMURLSessionTaskStateRunning;
    } else {
        _state = YMURLSessionTaskStateSuspended;
    }
}

- (void)startLoading {
    if (_internalState == YMURLSessionTaskInternalStateInitial) {
        if (!_originalRequest) {
            // TODO: error
        }

        if (_cachedResponse && [self canRespondFromCacheUsingResponse:_cachedResponse]) {
        } else {
            [self startNewTransferByRequest:_originalRequest];
        }
    }

    if (_internalState == YMURLSessionTaskInternalStateTransferReady) {
        _internalState = YMURLSessionTaskInternalStateTransferInProgress;
    }
}

- (BOOL)canRespondFromCacheUsingResponse:(NSCachedURLResponse *)response {
    // TODO:
    return true;
}

- (void)startNewTransferByRequest:(NSURLRequest *)request {
    if (!request.URL) {
        // TODO: error
    }

    [self getBodyWithCompletion:^(YMURLSessionTaskBody *body) {
        self.internalState = YMURLSessionTaskInternalStateTransferReady;
        self.transferState = [self createTransferStateWithURL:request.URL body:body workQueue:self.workQueue];
        NSURLRequest *r = self.authRequest ?: request;
        [self configureEasyHandleForRequest:r body:body];
        if (self.suspendCount < 1) {
            [self startLoading];
        }
    }];
}

- (void)getBodyWithCompletion:(void (^)(YMURLSessionTaskBody *body))completion {
    if (_knownBody) {
        completion(_knownBody);
        return;
    };

    if (_session && _session.delegate && [_session.delegate conformsToProtocol:@protocol(YMURLSessionTaskDelegate)] &&
        [_session.delegate respondsToSelector:@selector(YMURLSession:task:needNewBodyStream:)]) {
        id<YMURLSessionTaskDelegate> delegate = (id<YMURLSessionTaskDelegate>)_session.delegate;
        [delegate YMURLSession:_session
                          task:self
             needNewBodyStream:^(NSInputStream *_Nullable bodyStream) {
                 if (bodyStream) {
                     YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithInputStream:bodyStream];
                     completion(body);
                 } else {
                     YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] init];
                     completion(body);
                 }
             }];
    } else {
        YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] init];
        completion(body);
    }
}

- (void)configureEasyHandleForRequest:(NSURLRequest *)request body:(YMURLSessionTaskBody *)body {
}

- (YMTransferState *)createTransferStateWithURL:(NSURL *)url
                                           body:(YMURLSessionTaskBody *)body
                                      workQueue:(dispatch_queue_t)workQueue {
    YMDataDrain *drain = [self createTransferBodyDataDrain];
    switch (body.type) {
        case YMURLSessionTaskBodyTypeNone:
            return [[YMTransferState alloc] initWithURL:url dataDrain:drain];
            break;
        case YMURLSessionTaskBodyTypeData:
            // TODO: fix
            break;
        case YMURLSessionTaskBodyTypeFile:
            // TODO: fix
            break;
        case YMURLSessionTaskBodyTypeStream:
            // TODO: fix
            break;
        default:
            break;
    }
    return nil;
}

- (YMDataDrain *)createTransferBodyDataDrain {
    YMURLSession *s = _session;
    YMURLSessionTaskBehaviour *b = [s behaviourForTask:self];
    YMDataDrain *dd = [[YMDataDrain alloc] init];
    switch (b.type) {
        case YMURLSessionTaskBehaviourTypeNoDelegate:
            dd.type = YMDataDrainTypeIgnore;
            return dd;
        case YMURLSessionTaskBehaviourTypeTaskDelegate:
            dd.type = YMDataDrainTypeIgnore;
            return dd;
        case YMURLSessionTaskBehaviourTypeDataHandler:
            dd.type = YMDYMDataDraineInMemory;
            dd.data = nil;
            return dd;
        case YMURLSessionTaskBehaviourTypeDownloadHandler:
            // TODO: Download
            break;
    }
    return nil;
}

@end
