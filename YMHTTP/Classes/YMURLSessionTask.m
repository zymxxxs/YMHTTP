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

@interface YMURLSessionTask () <YMEasyHandleDelegate>

@property (nonatomic, strong) YMURLSession *session;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, assign) NSInteger suspendCount;
@property (nonatomic, strong) NSURLRequest *authRequest;

@property (nonatomic, strong) NSData *responseData;

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

@property BOOL hasTriggeredResume;
@property BOOL isDownloadTask;

@end

@implementation YMURLSessionTask {
    NSURLRequest *_currentRequest;
    NSHTTPURLResponse *_response;
}

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

    self.protocolLock = [[NSLock alloc] init];
    self.protocolState = YMURLSessionTaskProtocolStateToBeCreate;
}

- (void)resume {
    dispatch_sync(_workQueue, ^{
        if (self.state == YMURLSessionTaskStateCanceling || self.state == YMURLSessionTaskStateCompleted) return;
        self.suspendCount -= 1;
        if (_suspendCount < 0) {
            YM_FATALERROR(@"Resuming a task that's not suspended. Calls to resume() / suspend() need to be matched.");
        }
        [self updateTaskState];
        if (_suspendCount == 0) {
            self.hasTriggeredResume = true;
            [self getProtocolWithCompletion:^(BOOL isContinue) {
                if (self.suspendCount != 0) return;
                BOOL isHTTPScheme = [self.originalRequest.URL.scheme isEqualToString:@"http"] ||
                                    [self.originalRequest.URL.scheme isEqualToString:@"https"];
                if (isHTTPScheme && isContinue) {
                    dispatch_async(self.workQueue, ^{
                        [self startLoading];
                    });
                } else {
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
            }];
        }
    });
}

- (void)suspend {
    dispatch_sync(_workQueue, ^{
        if (self.state == YMURLSessionTaskStateCanceling || self.state == YMURLSessionTaskStateCompleted) return;
        self.suspendCount += 1;
        if (_suspendCount >= NSIntegerMax) {
            YM_FATALERROR(@"Task suspended too many times NSIntegerMax.");
        }
        [self updateTaskState];

        if (self.suspendCount == 1) {
            [self getProtocolWithCompletion:^(BOOL isContinue) {
                if (self.suspendCount != 1) return;
                dispatch_async(self.workQueue, ^{
                    [self stopLoading];
                });
            }];
        }
    });
}

- (void)cancel {
    dispatch_sync(_workQueue, ^{
        if (_state == YMURLSessionTaskStateRunning || _state == YMURLSessionTaskStateSuspended) {
            self.state = YMURLSessionTaskStateCanceling;
            [self getProtocolWithCompletion:^(BOOL isContinue) {
                dispatch_async(self.workQueue, ^{
                    NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain
                                                            code:NSURLErrorCancelled
                                                        userInfo:nil];
                    self.error = urlError;

                    if (isContinue) {
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
            NSURLRequestCachePolicy cachePolicy = self.session.configuration.requestCachePolicy;
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
        default:
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

- (void)setInternalState:(YMURLSessionTaskInternalState)internalState {
    YMURLSessionTaskInternalState newValue = internalState;
    if (![self isEasyHandlePausedForState:_internalState] && [self isEasyHandlePausedForState:newValue]) {
        [_easyHandle pauseReceive];
    }

    if ([self isEasyHandleAddedToMultiHandleForState:_internalState] &&
        ![self isEasyHandleAddedToMultiHandleForState:newValue]) {
        [_session removeHandle:_easyHandle];
    }

    // set
    YMURLSessionTaskInternalState oldValue = _internalState;
    _internalState = internalState;

    if (![self isEasyHandleAddedToMultiHandleForState:oldValue] &&
        [self isEasyHandleAddedToMultiHandleForState:_internalState]) {
        [_session addHandle:_easyHandle];
    }

    if ([self isEasyHandlePausedForState:oldValue] && ![self isEasyHandlePausedForState:_internalState]) {
        [_easyHandle unpauseReceive];
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

#pragma mark - Private Methods

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
    if (!request.URL) {
        YM_FATALERROR(@"No URL in request.");
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
    BOOL debugLibcurl = NSProcessInfo.processInfo.environment[@"URLSessionDebugLibcurl"];
    [_easyHandle setVerboseMode:debugLibcurl];
    BOOL debugOutput = NSProcessInfo.processInfo.environment[@"URLSessionDebug"];
    [_easyHandle setDebugOutput:debugOutput task:self];
    [_easyHandle setPassHeadersToDataStream:false];
    [_easyHandle setProgressMeterOff:true];
    [_easyHandle setSkipAllSignalHandling:true];

    // Error Options:
    [_easyHandle setErrorBuffer:NULL];
    [_easyHandle setFailOnHTTPErrorCode:false];

    if (!request.URL) {
        YM_FATALERROR(@"No URL in request.");
    }
    [_easyHandle setURL:request.URL];

    if (request.ym_connectToHost) {
        [_easyHandle setConnectToHost:request.ym_connectToHost port:request.ym_connectToPort];
    }
    [_easyHandle setSessionConfig:_session.configuration];
    [_easyHandle setAllowedProtocolsToHTTPAndHTTPS];
    [_easyHandle setPreferredReceiveBufferSize:NSIntegerMax];

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
        [_easyHandle setUpload:false];
        [_easyHandle setRequestBodyLength:0];
    } else if (bodySize != nil) {
        self.countOfBytesExpectedToSend = bodySize.longLongValue;
        [_easyHandle setUpload:true];
        [_easyHandle setRequestBodyLength:bodySize.unsignedLongLongValue];
    } else if (bodySize == nil) {
        [_easyHandle setUpload:true];
        [_easyHandle setRequestBodyLength:-1];
    }

    [_easyHandle setFollowLocation:false];

    // The httpAdditionalHeaders from session configuration has to be added to the request.
    // The request.allHTTPHeaders can override the httpAdditionalHeaders elements. Add the
    // httpAdditionalHeaders from session configuration first and then append/update the
    // request.allHTTPHeaders so that request.allHTTPHeaders can override httpAdditionalHeaders.
    NSMutableDictionary *hh = [NSMutableDictionary dictionary];
    NSDictionary *HTTPAdditionalHeaders = _session.configuration.HTTPAdditionalHeaders ?: @{};
    NSDictionary *HTTPHeaders = request.allHTTPHeaderFields ?: @{};
    [hh addEntriesFromDictionary:[self transformLowercaseKeyForHTTPHeaders:HTTPAdditionalHeaders]];
    [hh addEntriesFromDictionary:[self transformLowercaseKeyForHTTPHeaders:HTTPHeaders]];

    NSArray *curlHeaders = [self curlHeadersForHTTPHeaders:hh];
    if ([request.HTTPMethod isEqualToString:@"POST"] && (request.HTTPBody.length > 0) &&
        ([request valueForHTTPHeaderField:@"Content-Type"] == nil)) {
        NSMutableArray *temp = [curlHeaders mutableCopy];
        [temp addObject:@"Content-Type:application/x-www-form-urlencoded"];
        curlHeaders = temp;
    }
    [_easyHandle setCustomHeaders:curlHeaders];

    // TODO: timeoutInterval set or get
    NSInteger timeoutInterval = [self.session.configuration timeoutIntervalForRequest] * 1000;
    _easyHandle.timeoutTimer = [[YMTimeoutSource alloc]
        initWithQueue:_workQueue
         milliseconds:timeoutInterval
              handler:^{
                  self.internalState = YMURLSessionTaskInternalStateTransferFailed;
                  NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
                  [self completeTaskWithError:urlError];
                  [self notifyDelegateAboutError:urlError];
              }];
    [_easyHandle setAutomaticBodyDecompression:true];
    [_easyHandle setRequestMethod:request.HTTPMethod ?: @"GET"];
    if ([request.HTTPMethod isEqualToString:@"HEAD"]) {
        [_easyHandle setNoBody:true];
    }
    [_easyHandle setProxy];
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
            NSUnderlyingErrorKey : error,
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

    YMDataDrain *bodyData = _transferState.bodyDataDrain;
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
    _error = error;
    if (self.internalState != YMURLSessionTaskInternalStateTransferFailed) {
        YM_FATALERROR(@"Trying to complete the task, but its transfer isn't complete / failed.");
    }

    _easyHandle.timeoutTimer = nil;
    self.internalState = YMURLSessionTaskInternalStateTaskCompleted;
}

- (BOOL)isDataTask {
    return ![self isDownloadTask];
}

#pragma mark - Redirect Methods

- (void)redirectForRequest:(NSURLRequest *)reqeust {
    if (self.internalState != YMURLSessionTaskInternalStateTransferCompleted) {
        YM_FATALERROR(@"Trying to redirect, but the transfer is not complete.");
    }
    YMURLSessionTaskBehaviour *b = [_session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        BOOL isResponds = [_session.delegate
            respondsToSelector:@selector(YMURLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)];
        if (isResponds) {
            self.internalState = YMURLSessionTaskInternalStateWaitingForRedirectHandler;
            [_session.delegateQueue addOperationWithBlock:^{
                id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;
                [d YMURLSession:self.session
                                          task:self
                    willPerformHTTPRedirection:self.transferState.response
                                    newRequest:reqeust
                             completionHandler:^(NSURLRequest *_Nullable request) {
                                 dispatch_async(self.workQueue, ^{
                                     if (self.internalState != YMURLSessionTaskInternalStateTransferCompleted) {
                                         YM_FATALERROR(@"Received callback for HTTP redirection, but we're not waiting "
                                                       @"for it. Was it called multiple times?");
                                     }
                                     if (request) {
                                         [self startNewTransferByRequest:request];
                                     } else {
                                         self.internalState = YMURLSessionTaskInternalStateTransferCompleted;
                                         [self completeTask];
                                     }
                                 });
                             }];
            }];
        } else {
            NSURLRequest *configuredRequest = [_session.configuration configureRequest:reqeust];
            [self startNewTransferByRequest:configuredRequest];
        }
    } else {
        NSURLRequest *configuredRequest = [_session.configuration configureRequest:reqeust];
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
        case 303:
            method = @"GET";
            break;
        case 307:
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
    }

    request.URL = [NSURL URLWithString:urlString];
    double timeSpent = [_easyHandle getTimeoutIntervalSpent];
    request.timeoutInterval = fromRequest.timeoutInterval - timeSpent;
    return request;
}

#pragma mark - Task Processing

- (void)startLoading {
    if (self.internalState == YMURLSessionTaskInternalStateInitial) {
        if (!_originalRequest) {
            YM_FATALERROR(@"Task has no original request.");
        }

        void (^usingLocalCache)(void) = ^{
            self.internalState = YMURLSessionTaskInternalStateFulfillingFromCache;
            dispatch_async(self.workQueue, ^{
                [self notifyDelegateAboutReceiveResponse:(NSHTTPURLResponse *)self.cachedResponse.response];
                if (self.cachedResponse.data) {
                    self.responseData = self.cachedResponse.data;
                    [self notifyDelegateAboutReceiveData:self.cachedResponse.data];
                }
                [self notifyDelegateAboutFinishLoading];
                self.internalState = YMURLSessionTaskInternalStateTaskCompleted;
            });
        };

        NSURLRequestCachePolicy cachePolicy = self.session.configuration.requestCachePolicy;
        switch (cachePolicy) {
            case NSURLRequestUseProtocolCachePolicy: {
                if (self.cachedResponse && [self canRespondFromCacheUsingResponse:self.cachedResponse]) {
                    usingLocalCache();
                } else {
                    [self startNewTransferByRequest:self.originalRequest];
                }
                break;
            }
            case NSURLRequestReloadIgnoringLocalCacheData: {
                [self startNewTransferByRequest:self.originalRequest];
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
            case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            case NSURLRequestReloadRevalidatingCacheData:
            default: {
                [self startNewTransferByRequest:_originalRequest];
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
        if (!_error) {
            YM_FATALERROR(nil);
        }
        [self completeTaskWithError:_error];
    }
}

#pragma mark - Notify Delegate

- (void)notifyDelegateAboutReceiveData:(NSData *)data {
    if (self.cacheableData) {
        [self.cacheableData addObject:data];
    }

    YMURLSessionTaskBehaviour *b = [_session behaviourForTask:self];
    if (b.type != YMURLSessionTaskBehaviourTypeTaskDelegate) return;

    id<YMURLSessionDelegate> delegate = _session.delegate;

    BOOL conformsToDataDelegate = delegate && [delegate conformsToProtocol:@protocol(YMURLSessionDataDelegate)] &&
                                  [delegate respondsToSelector:@selector(YMURLSession:task:didReceiveData:)];
    if (conformsToDataDelegate && [self isDataTask]) {
        [_session.delegateQueue addOperationWithBlock:^{
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
    YMURLSessionTaskBehaviour *b = [_session behaviourForTask:self];
    switch (b.type) {
        case YMURLSessionTaskBehaviourTypeTaskDelegate: {
            [_session.delegateQueue addOperationWithBlock:^{
                if (self.state != YMURLSessionTaskStateCompleted) {
                    id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)self.session.delegate;
                    if (d && [d respondsToSelector:@selector(YMURLSession:task:didCompleteWithError:)]) {
                        [d YMURLSession:self.session task:self didCompleteWithError:error];
                    }

                    self->_state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }
            }];
            break;
        }
        case YMURLSessionTaskBehaviourTypeNoDelegate: {
            if (self.state != YMURLSessionTaskStateCompleted) {
                self->_state = YMURLSessionTaskStateCompleted;
                dispatch_async(self.workQueue, ^{
                    [self.session.taskRegistry removeWithTask:self];
                });
            }
            break;
        }
        case YMURLSessionTaskBehaviourTypeDataHandler: {
            [_session.delegateQueue addOperationWithBlock:^{
                if (self.state != YMURLSessionTaskStateCompleted) {
                    if (b.dataTaskCompeltion) b.dataTaskCompeltion(nil, nil, error);
                    self->_state = YMURLSessionTaskStateCompleted;
                    dispatch_async(self.workQueue, ^{
                        [self.session.taskRegistry removeWithTask:self];
                    });
                }
            }];
            break;
        }
        case YMURLSessionTaskBehaviourTypeDownloadHandler: {
            [_session.delegateQueue addOperationWithBlock:^{
                if (self.state != YMURLSessionTaskStateCompleted) {
                    if (b.dataTaskCompeltion) b.downloadCompletion(nil, nil, error);
                    self->_state = YMURLSessionTaskStateCompleted;
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
    if (!self.response) {
        YM_FATALERROR(@"No response");
    }

    // TODO: AuthenticationChallenge

    //    if (_response.statusCode == 401) {
    //        NSURLProtectionSpace *protectionSpace = [self createProtectionSpaceWithResponse:_response];
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
    //            NSURLCredentialStorage *storage = _session.configuration.URLCredentialStorage;
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
    //    NSURLCredentialStorage *storage = _session.configuration.URLCredentialStorage;
    //    if (storage) {
    //        NSURLCredential *lastCredential = nil;
    //        NSURLProtectionSpace *lastProtectionSpace = nil;
    //
    //        [_protocolLock lock];
    //        lastCredential = self.lastCredential;
    //        lastProtectionSpace = self.lastProtectionSpace;
    //        [_protocolLock unlock];
    //
    //        if (lastProtectionSpace && lastCredential) {
    //            [storage setCredential:lastCredential forProtectionSpace:lastProtectionSpace];
    //        }
    //    }

    if (self.session.configuration.URLCache && self.cacheableData && self.cacheableResponse && [self isDataTask]) {
        NSMutableData *data = [NSMutableData data];
        for (NSData *d in self.cacheableData) {
            [data appendData:d];
        }
        NSCachedURLResponse *cacheable = [[NSCachedURLResponse alloc] initWithResponse:self.cacheableResponse
                                                                                  data:data];
        BOOL protocolAllows = [YMURLCacheHelper canCacheResponse:cacheable request:self.currentRequest];
        if (protocolAllows) {
            id<YMURLSessionDelegate> delegate = self.session.delegate;
            if (delegate && [delegate conformsToProtocol:@protocol(YMURLSessionDataDelegate)] &&
                [delegate respondsToSelector:@selector(YMURLSession:task:willCacheResponse:completionHandler:)]) {
                id<YMURLSessionDataDelegate> d = (id<YMURLSessionDataDelegate>)delegate;
                [d YMURLSession:self.session
                                 task:self
                    willCacheResponse:cacheable
                    completionHandler:^(NSCachedURLResponse *_Nullable actualCacheable) {
                        if (actualCacheable) {
                            NSURLCache *cache = self.session.configuration.URLCache;
                            [cache ym_storeCachedResponse:cacheable forDataTask:self];
                        }
                    }];
            } else {
                NSURLCache *cache = self.session.configuration.URLCache;
                [cache ym_storeCachedResponse:cacheable forDataTask:self];
            }
        }
    }

    YMURLSessionTaskBehaviour *b = [_session behaviourForTask:self];
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
                self->_state = YMURLSessionTaskStateCompleted;
                dispatch_async(self.workQueue, ^{
                    [self.session.taskRegistry removeWithTask:self];
                });
            }];
            break;
        }
        case YMURLSessionTaskBehaviourTypeNoDelegate: {
            [_session.delegateQueue addOperationWithBlock:^{
                if (self.state == YMURLSessionTaskStateCompleted) return;
                self->_state = YMURLSessionTaskStateCompleted;
                dispatch_async(self.workQueue, ^{
                    [self.session.taskRegistry removeWithTask:self];
                });
            }];
            break;
        }
        case YMURLSessionTaskBehaviourTypeDataHandler: {
            [_session.delegateQueue addOperationWithBlock:^{
                if (self.state == YMURLSessionTaskStateCompleted) return;
                self->_state = YMURLSessionTaskStateCompleted;
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
            [_session.delegateQueue addOperationWithBlock:^{
                if (self.state == YMURLSessionTaskStateCompleted) return;
                self->_state = YMURLSessionTaskStateCompleted;
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
}

- (NSURLProtectionSpace *)createProtectionSpaceWithResponse:(NSHTTPURLResponse *)response {
    NSString *host = response.URL.host ?: @"";
    NSNumber *port = response.URL.port ?: @(80);
    NSString *protocol = response.URL.scheme;

    NSString *wwwAuthHeaderValue = response.allHeaderFields[@"WWW-Authenticate"];
    if (wwwAuthHeaderValue) {
        NSString *authMethod = [wwwAuthHeaderValue componentsSeparatedByString:@" "][0];
        NSString *realm = [wwwAuthHeaderValue componentsSeparatedByString:@"realm="][1];
        realm = [realm substringFromIndex:1];
        realm = [realm substringToIndex:realm.length - 1];

        NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:host
                                                                            port:port.integerValue
                                                                        protocol:protocol
                                                                           realm:realm
                                                            authenticationMethod:authMethod];
        return space;
    } else {
        return nil;
    }
}

- (void)notifyDelegateAboutReveiveChallenge:(NSURLAuthenticationChallenge *)challenge {
}

- (void)notifyDelegateAboutUploadedDataCount:(int64_t)count {
    YMURLSessionTaskBehaviour *b = [_session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate &&
        [self.session.delegate respondsToSelector:@selector
                               (YMURLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
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

    if (![self isDataTask]) return;

    NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:[NSData data]];
    BOOL isNeedStoreCache = [YMURLCacheHelper canCacheResponse:cachedResponse request:self.currentRequest];
    if (self.session.configuration.URLCache && isNeedStoreCache) {
        self.cacheableData = [[NSMutableArray alloc] init];
        self.cacheableResponse = response;
    }

    YMURLSessionTaskBehaviour *b = [_session behaviourForTask:self];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        if (_session.delegate &&
            [_session.delegate respondsToSelector:@selector(YMURLSession:task:didReceiveResponse:completionHandler:)]) {
            [self askDelegateHowToProceedAfterCompleteResponse:response];
        }
    }
}

- (void)askDelegateHowToProceedAfterCompleteResponse:(NSHTTPURLResponse *)response {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Transfer not in progress.");
    }

    self.internalState = YMURLSessionTaskInternalStateWaitingForResponseHandler;
    [_session.delegateQueue addOperationWithBlock:^{
        id<YMURLSessionDataDelegate> delegate = (id<YMURLSessionDataDelegate>)self.session.delegate;
        [delegate YMURLSession:self.session
                          task:self
            didReceiveResponse:response
             completionHandler:^(YMURLSessionResponseDisposition disposition) {
                 [self didCompleteResponseCallbackWithDisposition:disposition];
             }];
    }];
}

- (void)didCompleteResponseCallbackWithDisposition:(YMURLSessionResponseDisposition)disposition {
    if (self.internalState != YMURLSessionTaskInternalStateWaitingForResponseHandler) {
        YM_FATALERROR(@"Received response disposition, but we're not waiting for it.");
    }
    switch (disposition) {
        case YMURLSessionResponseCancel: {
            self.internalState = YMURLSessionTaskInternalStateTransferFailed;
            NSError *urlError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [self completeTaskWithError:urlError];
            [self notifyDelegateAboutError:urlError];
            break;
        }
        case YMURLSessionResponseAllow:
            self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
            break;
    }
}

#pragma mark - EasyHandle Delegate

- (YMEasyHandleAction)didReceiveWithHeaderData:(NSData *)data contentLength:(int64_t)contentLength {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Received header data, but no transfer in progress.");
    }

    NSError *error = nil;
    YMTransferState *ts = _transferState;
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
    if (!_transferState.response) {
        YM_FATALERROR(@"Header complete, but not URL response.");
    }

    NSHTTPURLResponse *response = self.transferState.response;
    switch (self.transferState.response.statusCode) {
        case 301:
        case 302:
        case 303:
        case 307:
            break;
        default:
            // 调用 notifyDelegateAboutReceiveResponse 缓存逻辑以及 askDelegateHowToProceedAfterCompleteResponse 逻辑
            [self notifyDelegateAboutReceiveResponse:response];
    }
}

- (YMEasyHandleAction)didReceiveWithData:(NSData *)data {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Received body data, but no transfer in progress.");
    }

    NSHTTPURLResponse *response = [self validateHeaderCompleteWithTS:_transferState];
    if (response) _transferState.response = response;
    [self notifyDelegateAboutReceiveData:data];
    self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
    _transferState = [_transferState byAppendingBodyData:data];
    return YMEasyHandleActionProceed;
}

- (NSHTTPURLResponse *)validateHeaderCompleteWithTS:(YMTransferState *)ts {
    if (!ts.isHeaderComplete) {
        return [[NSHTTPURLResponse alloc] initWithURL:ts.url statusCode:200 HTTPVersion:@"HTTP/0.9" headerFields:@{}];
    }
    return nil;
}

- (void)transferCompletedWithError:(NSError *)error {
    if (self.internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Transfer completed, but it wasn't in progress.");
    }

    if (!self.currentRequest) {
        YM_FATALERROR(@"Transfer completed, but there's no current request.");
    }

    if (error) {
        self.internalState = YMURLSessionTaskInternalStateTransferFailed;
        [self failWithError:error request:self.currentRequest];
        return;
    }

    if (self.response) {
        self.transferState.response = self.response;
    }

    NSHTTPURLResponse *response = self.transferState.response;
    if (!response) {
        YM_FATALERROR(@"Transfer completed, but there's no response.");
    }

    self.internalState = YMURLSessionTaskInternalStateTransferCompleted;
    NSURLRequest *rr = [self redirectedReqeustForResponse:response fromRequest:_currentRequest];
    if (rr) {
        [self redirectForRequest:rr];
    } else {
        [self completeTask];
    }
}

- (void)fillWriteBufferLength:(NSInteger)length
                       result:(void (^)(YMEasyHandleWriteBufferResult, NSInteger, NSData *_Nullable))result {
    if (_internalState != YMURLSessionTaskInternalStateTransferInProgress) {
        YM_FATALERROR(@"Requested to fill write buffer, but transfer isn't in progress.");
    }

    id<YMURLSessionTaskBodySource> source = _transferState.requestBodySource;

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

    if (_session.delegate && [_session.delegate conformsToProtocol:@protocol(YMURLSessionTaskDelegate)] &&
        [_session.delegate respondsToSelector:@selector(YMURLSession:task:needNewBodyStream:)]) {
        id<YMURLSessionTaskDelegate> d = (id<YMURLSessionTaskDelegate>)_session.delegate;

        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        [d YMURLSession:_session
                         task:self
            needNewBodyStream:^(NSInputStream *_Nullable bodyStream) {
                currentInputStream = bodyStream;
                dispatch_group_leave(group);
            }];
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 7 * NSEC_PER_SEC);
        dispatch_group_wait(group, timeout);
    }

    if (_originalRequest.URL && currentInputStream) {
        if (self.internalState == YMURLSessionTaskInternalStateTransferInProgress) {
            if ([_transferState.requestBodySource isKindOfClass:[YMBodyStreamSource class]]) {
                BOOL result = [currentInputStream ym_seekToPosition:position];
                if (!result) return false;
                YMDataDrain *drain = [self createTransferBodyDataDrain];
                YMBodyStreamSource *source = [[YMBodyStreamSource alloc] initWithInputStream:currentInputStream];
                YMTransferState *ts = [[YMTransferState alloc] initWithURL:_originalRequest.URL
                                                             bodyDataDrain:drain
                                                                bodySource:source];
                self.internalState = YMURLSessionTaskInternalStateTransferInProgress;
                _transferState = ts;
                return true;
            } else {
                YM_FATALERROR(nil);
            }
        }
    }

    return NO;
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
    if (_knownBody == nil) {
        return @[];
    } else if (_knownBody.type == YMURLSessionTaskBodyTypeNone) {
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
