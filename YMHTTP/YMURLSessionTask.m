//
//  YMURLSessionTask.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import "YMURLSessionTask.h"
#import "NSInputStream+YMCategory.h"
#import "NSURLCache+YMCategory.h"
#import "NSURLRequest+YMCategory.h"
#import "YMEasyHandle.h"
#import "YMMacro.h"
#import "YMTaskRegistry.h"
#import "YMTimeoutSource.h"
#import "YMTransferState.h"
#import "YMURLCacheHelper.h"
#import "YMURLSession.h"
#import "YMURLSessionAuthenticationChallengeSender.h"
#import "YMURLSessionConfiguration.h"
#import "YMURLSessionDelegate.h"
#import "YMURLSessionTaskBehaviour.h"
#import "YMURLSessionTaskBody.h"
#import "YMURLSessionTaskBodySource.h"

const int64_t YMURLSessionTransferSizeUnknown = -1;

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

typedef NS_ENUM(NSUInteger, YMURLSessionTaskProtocolState) {
    YMURLSessionTaskProtocolStateToBeCreate,
    YMURLSessionTaskProtocolStateAwaitingCacheReply,
    YMURLSessionTaskProtocolStateExisting,
    YMURLSessionTaskProtocolStateInvalidated
};

@interface YMURLSessionTask () <YMEasyHandleDelegate, NSProgressReporting>

@property (nonatomic, strong) YMURLSession *session;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, assign) NSInteger suspendCount;
@property (nonatomic, strong) NSURLRequest *authRequest;

@property (nonatomic, strong) NSData *responseData;
@property (nonatomic, strong) NSMutableData *lastRedirectBody;
@property (atomic) NSInteger redirectCount;

@property (nonatomic, strong) NSLock *protocolLock;
@property (nonatomic, assign) YMURLSessionTaskProtocolState protocolState;
@property (nonatomic, strong) NSMutableArray<void (^)(BOOL)> *protocolBag;
@property (nonatomic, strong) NSCachedURLResponse *cachedResponse;
@property (nonatomic, strong) NSHTTPURLResponse *cacheableResponse;
@property (nonatomic, strong) NSMutableArray<NSData *> *cacheableData;

@property (nonatomic, strong) YMEasyHandle *easyHandle;
@property (nonatomic, assign) YMURLSessionTaskInternalState internalState;
@property (nonatomic, strong) YMTransferState *transferState;
@property (nonatomic, strong) YMURLSessionTaskBody *knownBody;

@property (nonatomic, strong) NSURLProtectionSpace *lastProtectionSpace;
@property (nonatomic, strong) NSURLCredential *lastCredential;
@property (nonatomic, assign) NSInteger previousFailureCount;

@property (nonatomic, strong) NSURL *tempFileURL;

@property (readwrite) NSUInteger taskIdentifier;
@property (nullable, readwrite, copy) NSURLRequest *originalRequest;
@property (nullable, readwrite, copy) NSURLRequest *currentRequest;
@property (nullable, readwrite, copy) NSHTTPURLResponse *response;
@property (nullable, readwrite, copy) NSError *error;
@property (atomic, readwrite) YMURLSessionTaskState state;

@property (readwrite) int64_t countOfBytesReceived;
@property (readwrite) int64_t countOfBytesSent;
@property (readwrite) int64_t countOfBytesExpectedToSend;
@property (readwrite) int64_t countOfBytesExpectedToReceive;
@property (nonatomic, strong) dispatch_queue_t syncQ;
@property (readwrite) NSProgress *progress;

@property BOOL hasTriggeredResume;
@property BOOL isDownloadTask;

@end

@implementation YMURLSessionTask {
    int64_t _countOfBytesReceived;
    int64_t _countOfBytesSent;
    int64_t _countOfBytesExpectedToSend;
    int64_t _countOfBytesExpectedToReceive;
}

/// Create a data task. If there is a httpBody in the URLRequest, use that as a parameter
- (instancetype)initWithSession:(YMURLSession *)session
                        reqeust:(NSURLRequest *)request
                 taskIdentifier:(NSUInteger)taskIdentifier {
    if (request.HTTPBody && request.HTTPBody.length != 0) {
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

        self.session = session;
        self.workQueue = dispatch_queue_create_with_target(
            "com.zymxxxs.YMURLSessionTask.WrokQueue", DISPATCH_QUEUE_SERIAL, session.workQueue);
        self.taskIdentifier = taskIdentifier;
        self.originalRequest = request;
        self.knownBody = body;
        self.currentRequest = request;
    }
    return self;
}

- (void)setupProps {
    self.state = YMURLSessionTaskStateSuspended;
    self.suspendCount = 1;
    self.previousFailureCount = 0;
    self.redirectCount = 0;

    self.protocolLock = [[NSLock alloc] init];
    self.protocolState = YMURLSessionTaskProtocolStateToBeCreate;

    self.syncQ = dispatch_queue_create("com.zymxxxs.YMURLSessionTask.SyncQ", DISPATCH_QUEUE_SERIAL);
    self.progress = [NSProgress progressWithTotalUnitCount:-1];
}

- (void)resume {
    dispatch_sync(self.workQueue, ^{
        if (![self isCanResumeFromState]) return;
        if (self.suspendCount > 0) self.suspendCount -= 1;
        ;

        [self updateTaskState];
        if (self.suspendCount == 0) {
            self.hasTriggeredResume = true;
            [self checkOnlySupportHTTP];
            [self getProtocolWithCompletion:^(BOOL isContinue) {
                // 异步获取 local cache 之后，resume 所需的条件可能不存在，需要重新判断
                if (self.suspendCount != 0 || ![self isCanResumeFromState]) return;
                if (isContinue) {
                    dispatch_async(self.workQueue, ^{
                        [self startLoading];
                    });
                }
            }];
        }
    });
}

- (void)checkOnlySupportHTTP {
    NSString *scheme = self.originalRequest.URL.scheme;
    BOOL isHTTPScheme = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
    if (isHTTPScheme == false) {
        if (self.error == nil) {
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            userInfo[NSLocalizedDescriptionKey] = @"unsupported URL";
            NSURL *url = self.originalRequest.URL;
            if (url) {
                userInfo[NSURLErrorFailingURLErrorKey] = url;
                userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString;
            }
            NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain
                                                    code:NSURLErrorUnsupportedURL
                                                userInfo:userInfo];
            self.error = urlError;
            [self notifyDelegateAboutError:self.error];
        }
    }
}

- (void)suspend {
    dispatch_sync(self.workQueue, ^{
        if (self.state == YMURLSessionTaskStateCanceling || self.state == YMURLSessionTaskStateCompleted) return;
        self.suspendCount += 1;
        if (self.suspendCount >= NSIntegerMax) {
            YM_FATALERROR(@"Task suspended too many times NSIntegerMax.");
        }
        [self updateTaskState];

        if (self.suspendCount == 1) {
            [self getProtocolWithCompletion:^(BOOL isContinue) {
                // 异步获取 local cache 之后，suspend 所需的条件可能不存在，需要重新判断
                if (self.suspendCount != 1 || self.state == YMURLSessionTaskStateCanceling ||
                    self.state == YMURLSessionTaskStateCompleted)
                    return;
                dispatch_async(self.workQueue, ^{
                    if (isContinue) {
                        [self stopLoading];
                    }
                });
            }];
        }
    });
}

- (void)cancel {
    dispatch_sync(self.workQueue, ^{
        if (self.state == YMURLSessionTaskStateRunning || self.state == YMURLSessionTaskStateSuspended) {
            self.state = YMURLSessionTaskStateCanceling;
            [self getProtocolWithCompletion:^(BOOL isContinue) {
                dispatch_async(self.workQueue, ^{
                    if (isContinue) {
                        NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain
                                                                code:NSURLErrorCancelled
                                                            userInfo:nil];
                        self.error = urlError;
                        [self stopLoading];
                        [self notifyDelegateAboutError:urlError];
                    }
                });
            }];
        }
    });
}

- (void)getProtocolWithCompletion:(void (^)(BOOL isContinue))completion {
    [self.protocolLock lock];
    switch (self.protocolState) {
        case YMURLSessionTaskProtocolStateToBeCreate: {
            NSURLCache *cache = self.session.configuration.URLCache;
            NSURLRequestCachePolicy cachePolicy = self.currentRequest.cachePolicy;
            if (cache && [self isUsingLocalCacheWithPolicy:cachePolicy]) {
                self.protocolBag = [NSMutableArray array];
                [self.protocolBag addObject:completion];

                self.protocolState = YMURLSessionTaskProtocolStateAwaitingCacheReply;
                [self.protocolLock unlock];
                [cache ym_getCachedResponseForDataTask:self
                                     completionHandler:^(NSCachedURLResponse *_Nullable cachedResponse) {
                                         self.cachedResponse = cachedResponse;
                                         [self createEasyHandle];
                                         [self satisfyProtocolRequest];
                                     }];
            } else {
                [self createEasyHandle];
                self.protocolState = YMURLSessionTaskProtocolStateExisting;
                [self.protocolLock unlock];
                completion(true);
            }
            break;
        }

        case YMURLSessionTaskProtocolStateAwaitingCacheReply: {
            [self.protocolBag addObject:completion];
            [self.protocolLock unlock];
            break;
        }
        case YMURLSessionTaskProtocolStateExisting: {
            [self.protocolLock unlock];
            completion(true);
            break;
        }
        case YMURLSessionTaskProtocolStateInvalidated: {
            [self.protocolLock unlock];
            completion(false);
            break;
        }
    }
}

- (void)satisfyProtocolRequest {
    [self.protocolLock lock];
    switch (self.protocolState) {
        case YMURLSessionTaskProtocolStateToBeCreate: {
            self.protocolState = YMURLSessionTaskProtocolStateExisting;
            [self.protocolLock unlock];
            break;
        }
        case YMURLSessionTaskProtocolStateAwaitingCacheReply: {
            self.protocolState = YMURLSessionTaskProtocolStateExisting;
            [self.protocolLock unlock];

            for (void (^callback)(BOOL) in self.protocolBag) {
                callback(true);
            }
            self.protocolBag = nil;
            break;
        }
        case YMURLSessionTaskProtocolStateExisting:
        case YMURLSessionTaskProtocolStateInvalidated: {
            [self.protocolLock unlock];
            break;
        }
    }
}

- (BOOL)isUsingLocalCacheWithPolicy:(NSURLRequestCachePolicy)policy {
    switch (policy) {
        case NSURLRequestUseProtocolCachePolicy:
            return true;
        case NSURLRequestReloadIgnoringLocalCacheData:
            return false;
        case NSURLRequestReturnCacheDataElseLoad:
            return true;
        case NSURLRequestReturnCacheDataDontLoad:
            return true;
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
        case NSURLRequestReloadRevalidatingCacheData:
            return false;
    }
}

- (void)createEasyHandle {
    self.easyHandle = [[YMEasyHandle alloc] initWithDelegate:self];
    self.internalState = YMURLSessionTaskInternalStateInitial;
}

- (void)invalidateProtocol {
    [self.protocolLock lock];
    self.protocolState = YMURLSessionTaskProtocolStateInvalidated;
    [self.protocolLock unlock];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark - Setter Getter Methods

- (BOOL)isCanResumeFromState {
    return self.state != YMURLSessionTaskStateCanceling && self.state != YMURLSessionTaskStateCompleted;
}

- (void)setInternalState:(YMURLSessionTaskInternalState)internalState {
    @synchronized(self) {
        YMURLSessionTaskInternalState newValue = internalState;
        if (![self isEasyHandlePausedForState:_internalState] && [self isEasyHandlePausedForState:newValue]) {
            [self.easyHandle pauseReceive];
        }

        if ([self isEasyHandleAddedToMultiHandleForState:_internalState] &&
            ![self isEasyHandleAddedToMultiHandleForState:newValue]) {
            [self.session removeHandle:self.easyHandle];
        }

        // set
        YMURLSessionTaskInternalState oldValue = _internalState;
        _internalState = internalState;

        if (![self isEasyHandleAddedToMultiHandleForState:oldValue] &&
            [self isEasyHandleAddedToMultiHandleForState:_internalState]) {
            [self.session addHandle:self.easyHandle];
        }

        if ([self isEasyHandlePausedForState:oldValue] && ![self isEasyHandlePausedForState:_internalState]) {
            [self.easyHandle unpauseReceive];
        }
    }
}

- (BOOL)isEasyHandlePausedForState:(YMURLSessionTaskInternalState)state {
    switch (state) {
        case YMURLSessionTaskInternalStateInitial:
            return false;
        case YMURLSessionTaskInternalStateFulfillingFromCache:
            return false;
        case YMURLSessionTaskInternalStateTransferReady:
            return false;
        case YMURLSessionTaskInternalStateTransferInProgress:
            return false;
        case YMURLSessionTaskInternalStateTransferCompleted:
            return false;
        case YMURLSessionTaskInternalStateTransferFailed:
            return false;
        case YMURLSessionTaskInternalStateWaitingForRedirectHandler:
            return false;
        case YMURLSessionTaskInternalStateWaitingForResponseHandler:
            return true;
        case YMURLSessionTaskInternalStateTaskCompleted:
            return false;
    }
}

- (BOOL)isEasyHandleAddedToMultiHandleForState:(YMURLSessionTaskInternalState)state {
    switch (state) {
        case YMURLSessionTaskInternalStateInitial:
            return false;
        case YMURLSessionTaskInternalStateFulfillingFromCache:
            return false;
        case YMURLSessionTaskInternalStateTransferReady:
            return false;
        case YMURLSessionTaskInternalStateTransferInProgress:
            return true;
        case YMURLSessionTaskInternalStateTransferCompleted:
            return false;
        case YMURLSessionTaskInternalStateTransferFailed:
            return false;
        case YMURLSessionTaskInternalStateWaitingForRedirectHandler:
            return false;
        case YMURLSessionTaskInternalStateWaitingForResponseHandler:
            return true;
        case YMURLSessionTaskInternalStateTaskCompleted:
            return false;
    }
}

- (BOOL)isSuspendedAfterResume {
    return self.hasTriggeredResume && (self.state == YMURLSessionTaskStateSuspended);
}

- (NSURL *)tempFileURL {
    if (!_tempFileURL) {
        NSString *filePath = [NSString stringWithFormat:@"%@%@.tmp", NSTemporaryDirectory(), [NSUUID UUID].UUIDString];
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        _tempFileURL = [NSURL fileURLWithPath:filePath];
    }
    return _tempFileURL;
}

- (void)setCountOfBytesSent:(int64_t)countOfBytesSent {
    dispatch_sync(self.syncQ, ^{
        _countOfBytesSent = countOfBytesSent;
        [self updateProgress];
    });
}

- (int64_t)countOfBytesSent {
    __block int64_t value;
    dispatch_sync(self.syncQ, ^{
        value = _countOfBytesSent;
    });
    return value;
}

- (void)setCountOfBytesReceived:(int64_t)countOfBytesReceived {
    dispatch_sync(self.syncQ, ^{
        _countOfBytesReceived = countOfBytesReceived;
        [self updateProgress];
    });
}

- (int64_t)countOfBytesReceived {
    __block int64_t value;
    dispatch_sync(self.syncQ, ^{
        value = _countOfBytesReceived;
    });
    return value;
}

- (void)setCountOfBytesExpectedToSend:(int64_t)countOfBytesExpectedToSend {
    dispatch_sync(self.syncQ, ^{
        _countOfBytesExpectedToSend = countOfBytesExpectedToSend;
        [self updateProgress];
    });
}

- (int64_t)countOfBytesExpectedToSend {
    __block int64_t value;
    dispatch_sync(self.syncQ, ^{
        value = _countOfBytesExpectedToSend;
    });
    return value;
}

- (void)setCountOfBytesExpectedToReceive:(int64_t)countOfBytesExpectedToReceive {
    dispatch_sync(self.syncQ, ^{
        _countOfBytesExpectedToReceive = countOfBytesExpectedToReceive;
        [self updateProgress];
    });
}

- (int64_t)countOfBytesExpectedToReceive {
    __block int64_t value;
    dispatch_sync(self.syncQ, ^{
        value = _countOfBytesExpectedToReceive;
    });
    return value;
}

#pragma mark - Private Methods

- (void)updateProgress {
    dispatch_async(self.workQueue, ^{
        NSProgress *progress = self.progress;

        switch (self.state) {
            case YMURLSessionTaskStateCanceling:
            case YMURLSessionTaskStateCompleted: {
                int64_t total = progress.totalUnitCount;
                int64_t finalToal = total < 0 ? 1 : total;
                progress.totalUnitCount = finalToal;
                progress.completedUnitCount = finalToal;
                break;
            }
            default: {
                int64_t toBeSent;

                NSError *error = nil;
                NSNumber *bodySize = [self.knownBody getBodyLengthWithError:&error];
                if (error == nil && bodySize) {
                    toBeSent = [bodySize longLongValue];
                } else if (self.countOfBytesExpectedToSend > 0) {
                    toBeSent = self.countOfBytesExpectedToSend;
                } else {
                    toBeSent = YMURLSessionTransferSizeUnknown;
                }

                int64_t sent = self.countOfBytesSent;

                int64_t toBeReceived;
                if (self.countOfBytesExpectedToReceive > 0) {
                    toBeReceived = self.countOfBytesExpectedToReceive;
                } else {
                    toBeReceived = YMURLSessionTransferSizeUnknown;
                }

                int64_t received = self.countOfBytesReceived;

                progress.completedUnitCount = sent + received;

                if (toBeSent != YMURLSessionTransferSizeUnknown && toBeReceived != YMURLSessionTransferSizeUnknown) {
                    progress.totalUnitCount = toBeSent + toBeReceived;
                } else {
                    progress.totalUnitCount = YMURLSessionTransferSizeUnknown;
                }

                break;
            }
        }
    });
}

- (void)updateTaskState {
    if (self.suspendCount == 0) {
        self.state = YMURLSessionTaskStateRunning;
    } else {
        self.state = YMURLSessionTaskStateSuspended;
    }
}

- (BOOL)canRespondFromCacheUsingResponse:(NSCachedURLResponse *)response {
    BOOL canCache = [YMURLCacheHelper canCacheResponse:response request:self.currentRequest];
    if (!canCache) {
        NSURLCache *cache = self.session.configuration.URLCache;
        if (cache) {
            [cache ym_removeCachedResponseForDataTask:self];
        }
        return false;
    }
    return true;
}

- (void)startNewTransferByRequest:(NSURLRequest *)request {
    self.currentRequest = request;
    if (!request.URL) {
        YM_FATALERROR(@"No URL in request.");
    }

    [self getBodyWithCompletion:^(YMURLSessionTaskBody *body) {
        self.knownBody = body;
        self.internalState = YMURLSessionTaskInternalStateTransferReady;
        self.transferState = [self createTransferStateWithURL:request.URL body:body workQueue:self.workQueue];
        NSURLRequest *r = self.authRequest ?: request;
        [self configureEasyHandleForRequest:r body:body];
        if (self.suspendCount == 0) {
            [self startLoading];
        }
    }];
}

- (void)getBodyWithCompletion:(void (^)(YMURLSessionTaskBody *body))completion {
    if (self.knownBody) {
        completion(self.knownBody);
        return;
    };

    if (self.session && self.session.delegate &&
        [self.session.delegate conformsToProtocol:@protocol(YMURLSessionTaskDelegate)] &&
        [self.session.delegate respondsToSelector:@selector(YMURLSession:task:needNewBodyStream:)]) {
        id<YMURLSessionTaskDelegate> delegate = (id<YMURLSessionTaskDelegate>)self.session.delegate;
        [delegate YMURLSession:self.session
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
    if ([request.HTTPMethod isEqualToString:@"GET"]) {
        if (body.type != YMURLSessionTaskBodyTypeNone) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorDataLengthExceedsMaximum
                                             userInfo:@{
                                                 NSLocalizedDescriptionKey : @"resource exceeds maximum size",
                                                 NSURLErrorFailingURLStringErrorKey : [request.URL description] ?: @""
                                             }];
            self.internalState = YMURLSessionTaskInternalStateTransferFailed;
            [self transferCompletedWithError:error];
            return;
        }
    }

    BOOL debugLibcurl = NSProcessInfo.processInfo.environment[@"URLSessionDebugLibcurl"] ? true : false;
    [self.easyHandle setVerboseMode:debugLibcurl];
    BOOL debugOutput = NSProcessInfo.processInfo.environment[@"URLSessionDebug"] ? true : false;
    [self.easyHandle setDebugOutput:debugOutput task:self];
    [self.easyHandle setPassHeadersToDataStream:false];
    [self.easyHandle setProgressMeterOff:true];
    [self.easyHandle setSkipAllSignalHandling:true];

    // Error Options:
    [self.easyHandle setErrorBuffer:NULL];
    [self.easyHandle setFailOnHTTPErrorCode:false];

    if (!request.URL) {
        YM_FATALERROR(@"No URL in request.");
    }
    [self.easyHandle setURL:request.URL];

    if (request.ym_connectToHost) {
        [self.easyHandle setConnectToHost:request.ym_connectToHost port:request.ym_connectToPort];
    }
    [self.easyHandle setSessionConfig:self.session.configuration];
    [self.easyHandle setAllowedProtocolsToHTTPAndHTTPS];
    [self.easyHandle setPreferredReceiveBufferSize:NSIntegerMax];

    NSError *e = nil;
    NSNumber *bodySize = [body getBodyLengthWithError:&e];
    if (e) {
        self.internalState = YMURLSessionTaskInternalStateTransferFailed;
        NSInteger errorCode = [self errorCodeFromFileSystemError:e];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:errorCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"File system error"}];
        [self failWithError:error request:request];
        return;
    }
    if (body.type == YMURLSessionTaskBodyTypeNone) {
        if ([request.HTTPMethod isEqualToString:@"GET"]) {
            [self.easyHandle setUpload:false];
            [self.easyHandle setRequestBodyLength:0];
        } else {
            [self.easyHandle setUpload:true];
            [self.easyHandle setRequestBodyLength:0];
        }
    } else if (bodySize != nil) {
        self.countOfBytesExpectedToSend = bodySize.longLongValue;
        [self.easyHandle setUpload:true];
        [self.easyHandle setRequestBodyLength:bodySize.unsignedLongLongValue];
    } else if (bodySize == nil) {
        [self.easyHandle setUpload:true];
        [self.easyHandle setRequestBodyLength:-1];
    }

    [self.easyHandle setFollowLocation:false];

    // The httpAdditionalHeaders from session configuration has to be added to the request.
    // The request.allHTTPHeaders can override the httpAdditionalHeaders elements. Add the
    // httpAdditionalHeaders from session configuration first and then append/update the
    // request.allHTTPHeaders so that request.allHTTPHeaders can override httpAdditionalHeaders.
    NSMutableDictionary *hh = [NSMutableDictionary dictionary];
    NSDictionary *HTTPAdditionalHeaders = self.session.configuration.HTTPAdditionalHeaders ?: @{};
    NSDictionary *HTTPHeaders = request.allHTTPHeaderFields ?: @{};
    [hh addEntriesFromDictionary:[self transformLowercaseKeyForHTTPHeaders:HTTPAdditionalHeaders]];
    [hh addEntriesFromDictionary:[self transformLowercaseKeyForHTTPHeaders:HTTPHeaders]];

    NSArray *curlHeaders = [self curlHeadersForHTTPHeaders:hh];
    BOOL hasStream = request.HTTPBodyStream != nil;
    if (self.knownBody.type == YMURLSessionTaskBodyTypeStream) {
        hasStream = true;
    }
    if ([request.HTTPMethod isEqualToString:@"POST"] && ([request valueForHTTPHeaderField:@"Content-Type"] == nil) &&
        (request.HTTPBody.length > 0 || hasStream)) {
        NSMutableArray *temp = [curlHeaders mutableCopy];
        [temp addObject:@"Content-Type:application/x-www-form-urlencoded"];
        curlHeaders = temp;
    }
    [self.easyHandle setCustomHeaders:curlHeaders];

    NSInteger timeoutInterval = request.timeoutInterval * 1000;
    self.easyHandle.timeoutTimer = [[YMTimeoutSource alloc]
        initWithQueue:self.workQueue
         milliseconds:timeoutInterval
              handler:^{
                  if (self.internalState == YMURLSessionTaskInternalStateWaitingForRedirectHandler) {
                      self.response = self.transferState.response;
                      self.easyHandle.timeoutTimer = nil;
                      self.internalState = YMURLSessionTaskInternalStateTaskCompleted;
                  } else {
                      self.internalState = YMURLSessionTaskInternalStateTransferFailed;
                      NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain
                                                              code:NSURLErrorTimedOut
                                                          userInfo:nil];
                      [self completeTaskWithError:urlError];
                      [self notifyDelegateAboutError:urlError];
                  }
              }];
    [self.easyHandle setAutomaticBodyDecompression:true];
    [self.easyHandle setRequestMethod:request.HTTPMethod ?: @"GET"];
    // always set the status as it may change if a HEAD is converted to a GET
    [self.easyHandle setNoBody:[request.HTTPMethod isEqualToString:@"HEAD"]];
    [self.easyHandle setProxy];
}

- (YMTransferState *)createTransferStateWithURL:(NSURL *)url
                                           body:(YMURLSessionTaskBody *)body
                                      workQueue:(dispatch_queue_t)workQueue {
    YMDataDrain *drain = [self createTransferBodyDataDrain];
    switch (body.type) {
        case YMURLSessionTaskBodyTypeNone:
            return [[YMTransferState alloc] initWithURL:url bodyDataDrain:drain];
        case YMURLSessionTaskBodyTypeData: {
            YMBodyDataSource *source = [[YMBodyDataSource alloc] initWithData:body.data];
            return [[YMTransferState alloc] initWithURL:url bodyDataDrain:drain bodySource:source];
        }
        case YMURLSessionTaskBodyTypeFile: {
            YMBodyFileSource *source = [[YMBodyFileSource alloc] initWithFileURL:body.fileURL
                                                                       workQueue:workQueue
                                                            dataAvailableHandler:^{
                                                                [self.easyHandle unpauseSend];
                                                            }];
            return [[YMTransferState alloc] initWithURL:url bodyDataDrain:drain bodySource:source];
        }
        case YMURLSessionTaskBodyTypeStream: {
            YMBodyStreamSource *source = [[YMBodyStreamSource alloc] initWithInputStream:body.inputStream];
            return [[YMTransferState alloc] initWithURL:url bodyDataDrain:drain bodySource:source];
        }
    }
}

- (YMDataDrain *)createTransferBodyDataDrain {
    YMURLSession *s = self.session;
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
            dd.type = YMDataDrainInMemory;
            dd.data = nil;
            return dd;
        case YMURLSessionTaskBehaviourTypeDownloadHandler:
            dd.type = YMDataDrainTypeToFile;
            dd.fileHandle = [NSFileHandle fileHandleForWritingToURL:self.tempFileURL error:nil];
            dd.fileURL = self.tempFileURL;
            return dd;
    }
}

- (NSInteger)errorCodeFromFileSystemError:(NSError *)error {
    if (error.domain == NSCocoaErrorDomain) {
        switch (error.code) {
            case NSFileReadNoSuchFileError:
                return NSURLErrorFileDoesNotExist;
            case NSFileReadNoPermissionError:
                return NSURLErrorNoPermissionsToReadFile;
            default:
                return NSURLErrorUnknown;
        }
    } else {
        return NSURLErrorUnknown;
    }
}

- (void)failWithError:(NSError *)error request:(NSURLRequest *)request {
    NSDictionary *userInfo = nil;

    if (request.URL) {
        userInfo = @{
            NSURLErrorFailingURLErrorKey : request.URL,
            NSURLErrorFailingURLStringErrorKey : request.URL.absoluteString,
            NSLocalizedDescriptionKey : NSLocalizedString(error.localizedDescription, @"N/A")
        };
    }

    NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain code:error.code userInfo:userInfo];
    [self completeTaskWithError:urlError];
    [self notifyDelegateAboutError:urlError];
}

- (void)completeTask {
    if (self.internalState != YMURLSessionTaskInternalStateTransferCompleted) {
        YM_FATALERROR(@"Trying to complete the task, but its transfer isn't complete.");
    }

    self.response = self.transferState.response;
    self.easyHandle.timeoutTimer = nil;

    YMDataDrain *bodyData = self.transferState.bodyDataDrain;
    if (bodyData.type == YMDataDrainInMemory) {
        NSData *data = [NSData data];
        if (bodyData.data) {
            data = [[NSData alloc] initWithData:bodyData.data];
        }
        self.responseData = data;
    } else if (bodyData.type == YMDataDrainTypeToFile) {
        [bodyData.fileHandle closeFile];
    } else if ([self isDownloadTask]) {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:self.tempFileURL error:nil];
        [fileHandle closeFile];
    }

    [self notifyDelegateAboutFinishLoading];
    self.internalState = YMURLSessionTaskInternalStateTaskCompleted;
}

- (void)completeTaskWithError:(NSError *)error {
    self.error = error;
    if (self.internalState != YMURLSessionTaskInternalStateTransferFailed) {
        YM_FATALERROR(@"Trying to complete the task, but its transfer isn't complete / failed.");
    }

    self.easyHandle.timeoutTimer = nil;
    self.internalState = YMURLSessionTaskInternalStateTaskCompleted;
}

- (BOOL)isDataTask {
    return ![self isDownloadTask];
}

#pragma mark - Redirect Methods

- (void)redirectForRequest:(NSURLRequest *)request {
    if (self.internalState != YMURLSessionTaskInternalStateTransferCompleted) {
        YM_FATALERROR(@"Trying to redirect, but the transfer is not complete.");
    }

    self.redirectCount += 1;
    if (self.redirectCount > 16) {
        self.internalState = YMURLSessionTaskInternalStateTransferFailed;
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorHTTPTooManyRedirects
                                         userInfo:@{NSLocalizedDescriptionKey : @"too many HTTP redirects"}];
        if (!self.currentRequest) {
            YM_FATALERROR(@"In a redirect chain but no current task/request");
        }

        [self failWithError:error request:request];
        return;
    }

    YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        BOOL isResponds = [self.session.delegate
            respondsToSelector:@selector(YMURLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)];
        if (isResponds) {
            self.internalState = YMURLSessionTaskInternalStateWaitingForRedirectHandler;
            NSHTTPURLResponse *response = self.transferState.response;
            [self.session.delegateQueue addOperationWithBlock:^{
                id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;
                [d YMURLSession:self.session
                                          task:self
                    willPerformHTTPRedirection:response
                                    newRequest:request
                             completionHandler:^(NSURLRequest *_Nullable rr) {
                                 dispatch_async(self.workQueue, ^{
                                     if (self.internalState != YMURLSessionTaskInternalStateWaitingForRedirectHandler) {
                                         YM_FATALERROR(@"Received callback for HTTP redirection, but we're not waiting "
                                                       @"for it. Was it called multiple times?");
                                     }
                                     if (rr) {
                                         self.lastRedirectBody = nil;
                                         [self startNewTransferByRequest:rr];
                                     } else {
                                         // If the redirect is not followed, return the redirect itself as the response
                                         [self notifyDelegateAboutReceiveResponse:response];
                                         [self
                                             askDelegateHowToProceedAfterCompleteResponse:response
                                                                               completion:^(
                                                                                   BOOL isAsk,
                                                                                   YMURLSessionResponseDisposition
                                                                                       disposition) {
                                                                                   void (^continueNextProcess)(
                                                                                       void) = ^{
                                                                                       if (self.lastRedirectBody) {
                                                                                           [self
                                                                                               notifyDelegateAboutReceiveData:
                                                                                                   [self.lastRedirectBody
                                                                                                           copy]];
                                                                                       }
                                                                                       self.internalState =
                                                                                           YMURLSessionTaskInternalStateTransferCompleted;
                                                                                       [self completeTask];
                                                                                   };

                                                                                   if (!isAsk) {
                                                                                       continueNextProcess();
                                                                                   } else {
                                                                                       switch (disposition) {
                                                                                           case YMURLSessionResponseCancel: {
                                                                                               [self
                                                                                                   handleResponseCancelByDelegate];
                                                                                               break;
                                                                                           }
                                                                                           case YMURLSessionResponseAllow: {
                                                                                               continueNextProcess();
                                                                                               break;
                                                                                           }
                                                                                       }
                                                                                   }
                                                                               }];
                                     };
                                 });
                             }];
            }];
        } else {
            NSURLRequest *configuredRequest = [self.session.configuration configureRequest:request];
            [self startNewTransferByRequest:configuredRequest];
        }
    } else {
        NSURLRequest *configuredRequest = [self.session.configuration configureRequest:request];
        [self startNewTransferByRequest:configuredRequest];
    }
}

- (NSURLRequest *)redirectedReqeustForResponse:(NSHTTPURLResponse *)response fromRequest:(NSURLRequest *)fromRequest {
    NSString *method = nil;
    NSURL *targetURL = nil;

    if (!response.allHeaderFields) return nil;

    NSString *location = response.allHeaderFields[@"Location"];
    targetURL = [NSURL URLWithString:location];
    if (!location && !targetURL) return nil;

    switch (response.statusCode) {
        case 301:
        case 302:
            method = [fromRequest.HTTPMethod isEqualToString:@"POST"] ? @"GET" : fromRequest.HTTPMethod;
            break;
        case 303:
            method = @"GET";
            break;
        case 305:
        case 306:
        case 307:
        case 308:
            method = fromRequest.HTTPMethod ?: @"GET";
            break;
        default:
            return nil;
    }

    NSMutableURLRequest *request = [fromRequest mutableCopy];
    request.HTTPMethod = method;

    if (targetURL.scheme && targetURL.host) {
        request.URL = targetURL;
        return request;
    }

    NSString *scheme = request.URL.scheme;
    NSString *host = request.URL.host;
    NSNumber *port = request.URL.port;

    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = scheme;
    components.host = host;
    // Use the original port if the new URL does not contain a host
    // ie Location: /foo => <original host>:<original port>/Foo
    // but Location: newhost/foo  will ignore the original port
    if (targetURL.host == nil) {
        components.port = port;
    }
    // The path must either begin with "/" or be an empty string.
    if (![targetURL.relativePath hasPrefix:@"/"]) {
        components.path = [NSString stringWithFormat:@"/%@", targetURL.relativePath];
    } else {
        components.path = targetURL.relativePath;
    }

    NSString *urlString = components.string;
    if (!urlString) {
        // maybe need return nil
        YM_FATALERROR(@"Invalid URL");
        return nil;
    }

    request.URL = [NSURL URLWithString:urlString];
    // inherit the  timeout from the previous requesst
    request.timeoutInterval = fromRequest.timeoutInterval;
    return request;
}

#pragma mark - Task Processing

- (void)startLoading {
    if (self.internalState == YMURLSessionTaskInternalStateInitial) {
        if (!self.originalRequest) {
            YM_FATALERROR(@"Task has no original request.");
        }

        void (^usingLocalCache)(void) = ^{
            self.internalState = YMURLSessionTaskInternalStateFulfillingFromCache;
            dispatch_async(self.workQueue, ^{
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)self.cachedResponse.response;
                [self notifyDelegateAboutReceiveResponse:response];
                [self
                    askDelegateHowToProceedAfterCompleteResponse:response
                                                      completion:^(BOOL isAsk,
                                                                   YMURLSessionResponseDisposition disposition) {
                                                          void (^continueNextProcess)(void) = ^{
                                                              if (self.cachedResponse.data) {
                                                                  self.responseData = self.cachedResponse.data;
                                                                  [self
                                                                      notifyDelegateAboutReceiveData:self.cachedResponse
                                                                                                         .data];
                                                              }
                                                              [self notifyDelegateAboutFinishLoading];
                                                              self.internalState =
                                                                  YMURLSessionTaskInternalStateTaskCompleted;
                                                          };

                                                          if (!isAsk) {
                                                              continueNextProcess();
                                                          } else {
                                                              switch (disposition) {
                                                                  case YMURLSessionResponseCancel: {
                                                                      [self handleResponseCancelByDelegate];
                                                                      break;
                                                                  }
                                                                  case YMURLSessionResponseAllow: {
                                                                      continueNextProcess();
                                                                      break;
                                                                  }
                                                              }
                                                          }
                                                      }];
            });
        };

        NSURLRequestCachePolicy cachePolicy = self.originalRequest.cachePolicy;
        switch (cachePolicy) {
            case NSURLRequestUseProtocolCachePolicy: {
                if (self.cachedResponse && [self canRespondFromCacheUsingResponse:self.cachedResponse]) {
                    usingLocalCache();
                } else {
                    [self startNewTransferByRequest:self.originalRequest];
                }
                break;
            }
            case NSURLRequestReturnCacheDataElseLoad: {
                if (self.cachedResponse) {
                    usingLocalCache();
                } else {
                    [self startNewTransferByRequest:self.originalRequest];
                }
                break;
            }
            case NSURLRequestReturnCacheDataDontLoad: {
                if (self.cachedResponse) {
                    usingLocalCache();
                } else {
                    dispatch_async(self.workQueue, ^{
                        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                        userInfo[NSLocalizedDescriptionKey] = @"resource unavailable";
                        NSURL *url = self.originalRequest.URL;
                        if (url) {
                            userInfo[NSURLErrorFailingURLErrorKey] = url;
                            userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString;
                        }
                        NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain
                                                                code:NSURLErrorResourceUnavailable
                                                            userInfo:userInfo];
                        self.error = urlError;
                        [self stopLoading];
                        [self notifyDelegateAboutError:urlError];
                    });
                }
                break;
            }
            case NSURLRequestReloadIgnoringLocalCacheData:
            case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            case NSURLRequestReloadRevalidatingCacheData: {
                [self startNewTransferByRequest:self.originalRequest];
                break;
            }
        }
    }

    if (self.internalState == YMURLSessionTaskInternalStateTransferReady) {
        self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
    }
}

- (void)stopLoading {
    if (self.state == YMURLSessionTaskStateSuspended) {
        if (self.internalState == YMURLSessionTaskInternalStateTransferInProgress) {
            self.internalState = YMURLSessionTaskInternalStateTransferReady;
        }
    } else {
        self.internalState = YMURLSessionTaskInternalStateTransferFailed;
        if (!self.error) {
            YM_FATALERROR(nil);
        }
        [self completeTaskWithError:self.error];
    }
}

#pragma mark - Notify Delegate

- (void)notifyDelegateAboutReceiveData:(NSData *)data {
    if (self.cacheableData) {
        [self.cacheableData addObject:data];
    }

    YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
    if (b.type != YMURLSessionTaskBehaviourTypeTaskDelegate) return;

    id<YMURLSessionDelegate> delegate = self.session.delegate;

    BOOL conformsToDataDelegate = delegate && [delegate conformsToProtocol:@protocol(YMURLSessionDataDelegate)] &&
                                  [delegate respondsToSelector:@selector(YMURLSession:task:didReceiveData:)];
    if (conformsToDataDelegate && [self isDataTask]) {
        [self.session.delegateQueue addOperationWithBlock:^{
            id<YMURLSessionDataDelegate> d = (id<YMURLSessionDataDelegate>)delegate;
            [d YMURLSession:self.session task:self didReceiveData:data];
        }];
    };

    BOOL conformsToDownloadDelegate =
        delegate && [delegate conformsToProtocol:@protocol(YMURLSessionDownloadDelegate)] &&
        [delegate respondsToSelector:@selector(YMURLSession:
                                               downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)];
    if (conformsToDownloadDelegate && [self isDownloadTask]) {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:self.tempFileURL error:nil];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:data];

        self.countOfBytesReceived += [data length];
        [self.session.delegateQueue addOperationWithBlock:^{
            id<YMURLSessionDownloadDelegate> d = (id<YMURLSessionDownloadDelegate>)delegate;
            [d YMURLSession:self.session
                             downloadTask:self
                             didWriteData:[data length]
                        totalBytesWritten:self.countOfBytesReceived
                totalBytesExpectedToWrite:self.countOfBytesExpectedToReceive];
        }];
    }
}

- (void)notifyDelegateAboutError:(NSError *)error {
    YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
    switch (b.type) {
        case YMURLSessionTaskBehaviourTypeTaskDelegate: {
            [self.session.delegateQueue addOperationWithBlock:^{
                if (self.state != YMURLSessionTaskStateCompleted) {
                    id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;
                    if (d && [d respondsToSelector:@selector(YMURLSession:task:didCompleteWithError:)]) {
                        [d YMURLSession:self.session task:self didCompleteWithError:error];
                    }

                    self.state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }
            }];
            break;
        }
        case YMURLSessionTaskBehaviourTypeNoDelegate: {
            if (self.state != YMURLSessionTaskStateCompleted) {
                self.state = YMURLSessionTaskStateCompleted;
                dispatch_async(self.workQueue, ^{
                    [self.session.taskRegistry removeWithTask:self];
                });
            }
            break;
        }
        case YMURLSessionTaskBehaviourTypeDataHandler: {
            [self.session.delegateQueue addOperationWithBlock:^{
                if (self.state != YMURLSessionTaskStateCompleted) {
                    if (b.dataTaskCompeltion) b.dataTaskCompeltion(nil, nil, error);
                    self.state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }
            }];
            break;
        }
        case YMURLSessionTaskBehaviourTypeDownloadHandler: {
            [self.session.delegateQueue addOperationWithBlock:^{
                if (self.state != YMURLSessionTaskStateCompleted) {
                    if (b.downloadCompletion) b.downloadCompletion(nil, nil, error);
                    self.state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }
            }];
            break;
        }
    }
    [self invalidateProtocol];
}

- (void)notifyDelegateAboutFinishLoading {
    // TODO: AuthenticationChallenge

    //    if (self.response.statusCode == 401) {
    //        NSURLProtectionSpace *protectionSpace = [self createProtectionSpaceWithResponse:self.response];
    //
    //        void (^proceedProposingCredential)(NSURLCredential *) = ^(NSURLCredential *credential) {
    //            NSURLCredential *proposedCredential = nil;
    //            NSURLCredential *lastCredential = nil;
    //
    //            [self.protocolLock lock];
    //            lastCredential = self.lastCredential;
    //            [self.protocolLock unlock];
    //
    //            if ([lastCredential isEqual:credential]) {
    //                proposedCredential = credential;
    //            } else {
    //                proposedCredential = nil;
    //            }
    //
    //            YMURLSessionAuthenticationChallengeSender *sender =
    //                [[YMURLSessionAuthenticationChallengeSender alloc] init];
    //            NSURLAuthenticationChallenge *challenge =
    //                [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:protectionSpace
    //                                                           proposedCredential:proposedCredential
    //                                                         previousFailureCount:self.previousFailureCount
    //                                                              failureResponse:self.response
    //                                                                        error:nil
    //                                                                       sender:sender];
    //            self.previousFailureCount += 1;
    //            [self notifyDelegateAboutReveiveChallenge:challenge];
    //        };
    //
    //        if (protectionSpace) {
    //            NSURLCredentialStorage *storage = self.session.configuration.URLCredentialStorage;
    //            if (storage) {
    //                NSDictionary *credentials = storage.allCredentials[protectionSpace];
    //                if (credentials) {
    //                    NSArray *sortedKeys = [[credentials allKeys] sortedArrayUsingSelector:@selector(compare:)];
    //                    NSString *firstKey = [sortedKeys firstObject];
    //                    proceedProposingCredential(credentials[firstKey]);
    //                } else {
    //                    NSURLCredential *credential = [storage defaultCredentialForProtectionSpace:protectionSpace];
    //                    proceedProposingCredential(credential);
    //                }
    //            } else {
    //                NSURLCredential *credential = [storage defaultCredentialForProtectionSpace:protectionSpace];
    //                proceedProposingCredential(credential);
    //            }
    //        } else {
    //            proceedProposingCredential(nil);
    //        }
    //    }
    //
    //    NSURLCredentialStorage *storage = self.session.configuration.URLCredentialStorage;
    //    if (storage) {
    //        NSURLCredential *lastCredential = nil;
    //        NSURLProtectionSpace *lastProtectionSpace = nil;
    //
    //        [self.protocolLock lock];
    //        lastCredential = self.lastCredential;
    //        lastProtectionSpace = self.lastProtectionSpace;
    //        [self.protocolLock unlock];
    //
    //        if (lastProtectionSpace && lastCredential) {
    //            [storage setCredential:lastCredential forProtectionSpace:lastProtectionSpace];
    //        }
    //    }

    [self askDelegateHowToProceedProposedResponseCompletion:^{
        YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
        switch (b.type) {
            case YMURLSessionTaskBehaviourTypeTaskDelegate: {
                if ([self isDownloadTask] &&
                    [self.session.delegate respondsToSelector:@selector(YMURLSession:
                                                                        downloadTask:didFinishDownloadingToURL:)]) {
                    id<YMURLSessionDownloadDelegate> d = (id<YMURLSessionDownloadDelegate>)self.session.delegate;
                    [self.session.delegateQueue addOperationWithBlock:^{
                        [d YMURLSession:self.session downloadTask:self didFinishDownloadingToURL:self.tempFileURL];
                    }];
                }

                [self.session.delegateQueue addOperationWithBlock:^{
                    if (self.state == YMURLSessionTaskStateCompleted) return;
                    if ([self.session.delegate respondsToSelector:@selector(YMURLSession:task:didCompleteWithError:)]) {
                        id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;
                        [d YMURLSession:self.session task:self didCompleteWithError:nil];
                    }
                    self.state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }];
                break;
            }
            case YMURLSessionTaskBehaviourTypeNoDelegate: {
                [self.session.delegateQueue addOperationWithBlock:^{
                    if (self.state == YMURLSessionTaskStateCompleted) return;
                    self.state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }];
                break;
            }
            case YMURLSessionTaskBehaviourTypeDataHandler: {
                [self.session.delegateQueue addOperationWithBlock:^{
                    if (self.state == YMURLSessionTaskStateCompleted) return;
                    self.state = YMURLSessionTaskStateCompleted;
                    if (b.dataTaskCompeltion) {
                        NSData *data = self.responseData ?: [NSData data];
                        b.dataTaskCompeltion(data, self.response, nil);
                    }
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }];
                break;
            }
            case YMURLSessionTaskBehaviourTypeDownloadHandler: {
                [self.session.delegateQueue addOperationWithBlock:^{
                    if (self.state == YMURLSessionTaskStateCompleted) return;
                    self.state = YMURLSessionTaskStateCompleted;
                    if (b.downloadCompletion) {
                        NSURL *location = self.tempFileURL;
                        b.downloadCompletion(location, self.response, nil);
                    }
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }];
                break;
            }
        }

        [self invalidateProtocol];
    }];
}

- (void)askDelegateHowToProceedProposedResponseCompletion:(void (^)(void))completion {
    BOOL isWillCache =
        self.session.configuration.URLCache && self.cacheableData && self.cacheableResponse && [self isDataTask];
    if (!isWillCache) return completion();

    NSMutableData *data = [NSMutableData data];
    for (NSData *d in self.cacheableData) {
        [data appendData:d];
    }
    NSCachedURLResponse *cacheable = [[NSCachedURLResponse alloc] initWithResponse:self.cacheableResponse data:data];
    BOOL cacheProtocolAllows = [YMURLCacheHelper canCacheResponse:cacheable request:self.currentRequest];

    if (!cacheProtocolAllows) return completion();

    id<YMURLSessionDelegate> delegate = self.session.delegate;
    YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        if (delegate && [delegate conformsToProtocol:@protocol(YMURLSessionDataDelegate)] &&
            [delegate respondsToSelector:@selector(YMURLSession:task:willCacheResponse:completionHandler:)]) {
            id<YMURLSessionDataDelegate> d = (id<YMURLSessionDataDelegate>)delegate;
            [self.session.delegateQueue addOperationWithBlock:^{
                [d YMURLSession:self.session
                                 task:self
                    willCacheResponse:cacheable
                    completionHandler:^(NSCachedURLResponse *_Nullable actualCacheable) {
                        if (actualCacheable) {
                            NSURLCache *cache = self.session.configuration.URLCache;
                            [cache ym_storeCachedResponse:actualCacheable forDataTask:self];
                        }
                        return completion();
                    }];
            }];
        } else {
            NSURLCache *cache = self.session.configuration.URLCache;
            [cache ym_storeCachedResponse:cacheable forDataTask:self];
            return completion();
        }
    } else {
        NSURLCache *cache = self.session.configuration.URLCache;
        [cache ym_storeCachedResponse:cacheable forDataTask:self];
        return completion();
    }
}

//- (NSURLProtectionSpace *)createProtectionSpaceWithResponse:(NSHTTPURLResponse *)response {
//    NSString *host = response.URL.host ?: @"";
//    NSNumber *port = response.URL.port ?: @(80);
//    NSString *protocol = response.URL.scheme;
//
//    NSString *wwwAuthHeaderValue = response.allHeaderFields[@"WWW-Authenticate"];
//    if (wwwAuthHeaderValue) {
//        NSString *authMethod = [wwwAuthHeaderValue componentsSeparatedByString:@" "][0];
//        NSString *realm = [wwwAuthHeaderValue componentsSeparatedByString:@"realm="][1];
//        realm = [realm substringFromIndex:1];
//        realm = [realm substringToIndex:realm.length - 1];
//
//        NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:host
//                                                                            port:port.integerValue
//                                                                        protocol:protocol
//                                                                           realm:realm
//                                                            authenticationMethod:authMethod];
//        return space;
//    } else {
//        return nil;
//    }
//}
//
//- (void)notifyDelegateAboutReveiveChallenge:(NSURLAuthenticationChallenge *)challenge {
//}

- (void)notifyDelegateAboutUploadedDataCount:(int64_t)count {
    YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate &&
        [self.session.delegate
            respondsToSelector:@selector(YMURLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)]) {
        self.countOfBytesSent += count;
        [self.session.delegateQueue addOperationWithBlock:^{
            id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;
            [d YMURLSession:self.session
                                    task:self
                         didSendBodyData:count
                          totalBytesSent:self.countOfBytesSent
                totalBytesExpectedToSend:self.countOfBytesExpectedToSend];
        }];
    }
}

- (void)notifyDelegateAboutReceiveResponse:(NSHTTPURLResponse *)response {
    self.response = response;

    // only dataTask can cache
    if (![self isDataTask]) return;

    NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:[NSData data]];
    BOOL isNeedStoreCache = [YMURLCacheHelper canCacheResponse:cachedResponse request:self.currentRequest];
    if (self.session.configuration.URLCache && isNeedStoreCache) {
        self.cacheableData = [[NSMutableArray alloc] init];
        self.cacheableResponse = response;
    }
}

- (void)askDelegateHowToProceedAfterCompleteResponse:(NSHTTPURLResponse *)response
                                          completion:(void (^)(BOOL isAsk,
                                                               YMURLSessionResponseDisposition disposition))completion {
    // only dataTask can ask how to process
    if (![self isDataTask]) return completion(false, 0);

    // internal state is only support transferInProgress || fulfillingFromCache
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress &&
        self.internalState != YMURLSessionTaskInternalStateFulfillingFromCache &&
        self.internalState != YMURLSessionTaskInternalStateWaitingForRedirectHandler) {
        YM_FATALERROR(@"Transfer not in progress.");
    }

    YMURLSessionTaskBehaviour *b = [self.session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        BOOL isRespondDidReceiveResponse = [self.session.delegate
            respondsToSelector:@selector(YMURLSession:task:didReceiveResponse:completionHandler:)];
        if (isRespondDidReceiveResponse) {
            self.suspendCount += 1;
            self.state = YMURLSessionTaskStateSuspended;

            // pause easy handle
            if (self.internalState == YMURLSessionTaskInternalStateTransferInProgress) {
                self.internalState = YMURLSessionTaskInternalStateWaitingForResponseHandler;
            }
            [self.session.delegateQueue addOperationWithBlock:^{
                id<YMURLSessionDataDelegate> delegate = (id<YMURLSessionDataDelegate>)self.session.delegate;
                [delegate YMURLSession:self.session
                                  task:self
                    didReceiveResponse:response
                     completionHandler:^(YMURLSessionResponseDisposition disposition) {
                         if (self.internalState == YMURLSessionTaskInternalStateWaitingForResponseHandler ||
                             self.internalState == YMURLSessionTaskInternalStateFulfillingFromCache ||
                             self.internalState == YMURLSessionTaskInternalStateWaitingForRedirectHandler) {
                             return completion(true, disposition);
                         }
                     }];
            }];
        } else {
            return completion(false, 0);
        }
    } else {
        return completion(false, 0);
    }
}

#pragma mark - EasyHandle Delegate

- (YMEasyHandleAction)didReceiveWithHeaderData:(NSData *)data contentLength:(int64_t)contentLength {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Received header data, but no transfer in progress.");
    }

    NSError *error = nil;
    YMTransferState *ts = self.transferState;
    YMTransferState *newTS = [ts byAppendingHTTPHeaderLineData:data error:&error];
    if (error) {
        return YMEasyHandleActionAbort;
    }

    self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
    self.transferState = newTS;

    if (!ts.isHeaderComplete && newTS.isHeaderComplete) {
        NSHTTPURLResponse *response = newTS.response;
        NSString *contentEncoding = response.allHeaderFields[@"Content-Encoding"];
        if (![contentEncoding isEqualToString:@"identify"]) {
            self.countOfBytesExpectedToReceive = YMURLSessionTransferSizeUnknown;
        } else {
            self.countOfBytesExpectedToReceive = contentLength > 0 ?: YMURLSessionTransferSizeUnknown;
        }
        [self didReceiveResponse];
    }

    return YMEasyHandleActionProceed;
}

- (void)didReceiveResponse {
    if (![self isDataTask]) return;

    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Transfer not in progress.");
    }
    if (!self.transferState.response) {
        YM_FATALERROR(@"Header complete, but not URL response.");
    }

    NSHTTPURLResponse *response = self.transferState.response;
    switch (self.transferState.response.statusCode) {
        case 301:
        case 302:
        case 303:
        case 305:
        case 306:
        case 307:
        case 308:
            break;
        default: {
            [self notifyDelegateAboutReceiveResponse:response];
            [self askDelegateHowToProceedAfterCompleteResponse:response
                                                    completion:^(BOOL isAsk,
                                                                 YMURLSessionResponseDisposition disposition) {
                                                        if (!isAsk) return;
                                                        switch (disposition) {
                                                            case YMURLSessionResponseCancel: {
                                                                [self handleResponseCancelByDelegate];
                                                                break;
                                                            }
                                                            case YMURLSessionResponseAllow: {
                                                                self.internalState =
                                                                    YMURLSessionTaskInternalStateTransferInProgress;
                                                                break;
                                                            }
                                                        }
                                                    }];
        }
    }
}

- (void)handleResponseCancelByDelegate {
    if (self.internalState != YMURLSessionTaskInternalStateTransferFailed) {
        self.internalState = YMURLSessionTaskInternalStateTransferFailed;
        NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
        [self completeTaskWithError:urlError];
        [self notifyDelegateAboutError:urlError];
    }
}

- (YMEasyHandleAction)didReceiveWithData:(NSData *)data {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Received body data, but no transfer in progress.");
    }

    NSHTTPURLResponse *response = [self validateHeaderCompleteWithTS:self.transferState];
    if (response) self.transferState.response = response;

    // Note this excludes code 300 which should return the response of the redirect and not follow it.
    // For other redirect codes dont notify the delegate of the data received in the redirect response.
    if (response.statusCode >= 301 && response.statusCode <= 308) {
        if (!self.lastRedirectBody) {
            self.lastRedirectBody = [[NSMutableData alloc] init];
        }
        [self.lastRedirectBody appendData:data];

        return YMEasyHandleActionProceed;
    }

    [self notifyDelegateAboutReceiveData:data];
    self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
    self.transferState = [self.transferState byAppendingBodyData:data];
    return YMEasyHandleActionProceed;
}

- (NSHTTPURLResponse *)validateHeaderCompleteWithTS:(YMTransferState *)ts {
    if (!ts.isHeaderComplete) {
        return [[NSHTTPURLResponse alloc] initWithURL:ts.url statusCode:200 HTTPVersion:@"HTTP/0.9" headerFields:@{}];
    }
    return nil;
}

- (void)transferCompletedWithError:(NSError *)error {
    if (error) {
        self.internalState = YMURLSessionTaskInternalStateTransferFailed;
        [self failWithError:error request:self.currentRequest];
        return;
    }

    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Transfer completed, but it wasn't in progress.");
    }

    if (!self.currentRequest) {
        YM_FATALERROR(@"Transfer completed, but there's no current request.");
    }

    if (self.response) {
        self.transferState.response = self.response;
    }

    NSHTTPURLResponse *response = self.transferState.response;
    if (!response) {
        YM_FATALERROR(@"Transfer completed, but there's no response.");
    }

    self.internalState = YMURLSessionTaskInternalStateTransferCompleted;
    NSURLRequest *rr = [self redirectedReqeustForResponse:response fromRequest:self.currentRequest];
    if (rr) {
        [self redirectForRequest:rr];
    } else {
        [self completeTask];
    }
}

- (void)fillWriteBufferLength:(NSInteger)length
                       result:(void (^)(YMEasyHandleWriteBufferResult, NSInteger, NSData *_Nullable))result {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Requested to fill write buffer, but transfer isn't in progress.");
    }

    id<YMURLSessionTaskBodySource> source = self.transferState.requestBodySource;

    if (!source) {
        YM_FATALERROR(@"Requested to fill write buffer, but transfer state has no body source.");
    }

    if (!result) return;

    [source getNextChunkWithLength:length
                 completionHandler:^(YMBodySourceDataChunk chunk, NSData *_Nullable data) {
                     switch (chunk) {
                         case YMBodySourceDataChunkData: {
                             NSUInteger count = data.length;
                             [self notifyDelegateAboutUploadedDataCount:(int64_t)count];
                             result(YMEasyHandleWriteBufferResultBytes, count, data);
                             break;
                         }
                         case YMBodySourceDataChunkDone:
                             result(YMEasyHandleWriteBufferResultBytes, 0, nil);
                             break;
                         case YMBodySourceDataChunkRetryLater:
                             result(YMEasyHandleWriteBufferResultPause, -1, nil);
                             break;
                         case YMBodySourceDataChunkError:
                             result(YMEasyHandleWriteBufferResultAbort, -1, nil);
                             break;
                     }
                 }];
}

- (BOOL)seekInputStreamToPosition:(uint64_t)position {
    __block NSInputStream *currentInputStream = nil;

    if (self.session.delegate && [self.session.delegate conformsToProtocol:@protocol(YMURLSessionTaskDelegate)] &&
        [self.session.delegate respondsToSelector:@selector(YMURLSession:task:needNewBodyStream:)]) {
        id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;

        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        [d YMURLSession:self.session
                         task:self
            needNewBodyStream:^(NSInputStream *_Nullable bodyStream) {
                currentInputStream = bodyStream;
                dispatch_group_leave(group);
            }];
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_group_wait(group, timeout);
    }

    if (self.originalRequest.URL && currentInputStream) {
        if (self.internalState == YMURLSessionTaskInternalStateTransferInProgress) {
            if ([self.transferState.requestBodySource isKindOfClass:[YMBodyStreamSource class]]) {
                BOOL result = [currentInputStream ym_seekToPosition:position];
                if (!result) return false;
                YMDataDrain *drain = [self createTransferBodyDataDrain];
                YMBodyStreamSource *source = [[YMBodyStreamSource alloc] initWithInputStream:currentInputStream];
                YMTransferState *ts = [[YMTransferState alloc] initWithURL:self.originalRequest.URL
                                                             bodyDataDrain:drain
                                                                bodySource:source];
                self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
                self.transferState = ts;
                return true;
            } else {
                YM_FATALERROR(nil);
            }
        }
    }

    return NO;
}

- (void)needTimeoutTimerToValue:(NSInteger)value {
    [self.session updateTimeoutTimerToValue:value];
}

- (void)updateProgressMeterWithTotalBytesSent:(int64_t)totalBytesSent
                     totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
                           totalBytesReceived:(int64_t)totalBytesReceived
                  totalBytesExpectedToReceive:(int64_t)totalBytesExpectedToReceive {
    if (!self.progress) return;

    self.progress.totalUnitCount = totalBytesExpectedToReceive + totalBytesExpectedToSend;
    self.progress.completedUnitCount = totalBytesReceived + totalBytesSent;
}

#pragma mark - Headers Methods

- (NSDictionary *)transformLowercaseKeyForHTTPHeaders:(NSDictionary *)HTTPHeaders {
    if (!HTTPHeaders) return nil;

    NSMutableDictionary *result = @{}.mutableCopy;
    for (NSString *key in [HTTPHeaders allKeys]) {
        result[[key lowercaseString]] = HTTPHeaders[key];
    }
    return [result copy];
}

- (NSArray<NSString *> *)curlHeadersForHTTPHeaders:(NSDictionary *)HTTPHeaders {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *names = [NSMutableSet set];

    for (NSString *key in [HTTPHeaders allKeys]) {
        NSString *name = [key lowercaseString];
        if ([names containsObject:name]) break;
        [names addObject:name];

        NSString *value = HTTPHeaders[key];
        if (value.length == 0) {
            [result addObject:[NSString stringWithFormat:@"%@;", key]];
        } else {
            [result addObject:[NSString stringWithFormat:@"%@: %@", key, value]];
        }
    }

    NSDictionary *curlHeadersToSet = [self curlHeadersToSet];
    for (NSString *key in [curlHeadersToSet allKeys]) {
        NSString *name = [key lowercaseString];
        if ([names containsObject:name]) break;
        [names addObject:name];

        NSString *value = curlHeadersToSet[key];
        if (value.length == 0) {
            [result addObject:[NSString stringWithFormat:@"%@;", key]];
        } else {
            [result addObject:[NSString stringWithFormat:@"%@: %@", key, value]];
        }
    }

    NSArray *curlHeadersToRemove = [self curlHeadersToRemove];
    for (NSString *key in curlHeadersToRemove) {
        NSString *name = [key lowercaseString];
        if ([names containsObject:name]) break;
        [names addObject:name];
        [result addObject:[NSString stringWithFormat:@"%@:", key]];
    }

    return result;
}

- (NSDictionary *)curlHeadersToSet {
    return @{
        @"Connection" : @"keep-alive",
        @"User-Agent" : [self userAgentString],
        @"Accept-Language" : [self acceptLanguageString]
    };
}

- (NSArray *)curlHeadersToRemove {
    if (self.knownBody == nil) {
        return @[];
    } else if (self.knownBody.type == YMURLSessionTaskBodyTypeNone) {
        return @[];
    }
    return @[ @"Expect" ];
}

- (NSString *)userAgentString {
    // from AFNetworking
    NSString *userAgent = nil;
    userAgent = [NSString
        stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)",
                         [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey]
                             ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey],
                         [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"]
                             ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey],
                         [[UIDevice currentDevice] model],
                         [[UIDevice currentDevice] systemVersion],
                         [[UIScreen mainScreen] scale]];

    if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
        NSMutableString *mutableUserAgent = [userAgent mutableCopy];
        if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent),
                              NULL,
                              (__bridge CFStringRef) @"Any-Latin; Latin-ASCII; [:^ASCII:] Remove",
                              false)) {
            userAgent = mutableUserAgent;
        }
    }
    return userAgent;
}

- (NSString *)acceptLanguageString {
    // from AFNetworking
    NSMutableArray *acceptLanguagesComponents = [NSMutableArray array];
    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        float q = 1.0f - (idx * 0.1f);
        [acceptLanguagesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
        *stop = q <= 0.5f;
    }];
    return [acceptLanguagesComponents componentsJoinedByString:@", "];
}

@end
