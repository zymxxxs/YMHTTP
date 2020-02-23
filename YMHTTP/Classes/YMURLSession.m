//
//  YMURLSession.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

#import "YMURLSession.h"
#import "YMMacro.h"
#import "YMMultiHandle.h"
#import "YMTaskRegistry.h"
#import "YMURLSessionConfiguration.h"
#import "YMURLSessionTask.h"
#import "YMURLSessionTaskBehaviour.h"

static YMURLSession *_sharedSession = nil;

static dispatch_queue_t _globalVarSyncQ = nil;
static int sessionCounter = 0;
NS_INLINE int nextSessionIdentifier() {
    if (_globalVarSyncQ == nil) {
        _globalVarSyncQ = dispatch_queue_create("com.zymxxxs.URLSession.GlobalVarSyncQ", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_sync(_globalVarSyncQ, ^{
        sessionCounter += 1;
    });
    return sessionCounter;
}

@interface YMURLSession ()

@property (nonatomic, strong) YMMultiHandle *multiHandle;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, assign) int identifier;
@property (nonatomic, assign) BOOL invalidated;
@property (nonatomic, assign) NSUInteger nextTaskIdentifier;
@property (nullable, strong) id<YMURLSessionDelegate> delegate;

@end

@implementation YMURLSession

#pragma mark - Public Methods

- (instancetype)initWithConfiguration:(YMURLSessionConfiguration *)configuration
                             delegate:(id<YMURLSessionDelegate>)delegate
                        delegateQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        _taskRegistry = [[YMTaskRegistry alloc] init];
        ym_initializeLibcurl();
        _identifier = nextSessionIdentifier();
        _workQueue = dispatch_queue_create("", DISPATCH_QUEUE_SERIAL);
        if (queue) {
            _delegateQueue = queue;
        } else {
            _delegateQueue = [[NSOperationQueue alloc] init];
        }
        _delegateQueue.maxConcurrentOperationCount = 1;
        _delegate = delegate;
        _configuration = [configuration copy];
        _multiHandle = [[YMMultiHandle alloc] initWithConfiguration:_configuration WorkQueue:_workQueue];
    }
    return self;
}

+ (YMURLSession *)sharedSession {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        YMURLSessionConfiguration *configuration = [YMURLSessionConfiguration defaultSessionConfiguration];
        _sharedSession = [YMURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
    });
    return _sharedSession;
}

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration
                                  delegate:(id<YMURLSessionDelegate>)delegate
                             delegateQueue:(NSOperationQueue *)queue {
    return [[YMURLSession alloc] initWithConfiguration:configuration delegate:delegate delegateQueue:queue];
}

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration {
    return [self sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
}

- (void)finishTasksAndInvalidate {
    dispatch_async(_workQueue, ^{
        self.invalidated = true;

        void (^invalidateSessionCallback)(void) = ^{
            if (!self.delegate) return;
            [self.delegateQueue addOperationWithBlock:^{
                if ([self.delegate respondsToSelector:@selector(YMURLSession:didBecomeInvalidWithError:)]) {
                    [self.delegate YMURLSession:self didBecomeInvalidWithError:nil];
                }
                self.delegate = nil;
            }];
        };

        if (!self.taskRegistry.isEmpty) {
            [self.taskRegistry notifyOnTasksCompletion:invalidateSessionCallback];
        } else {
            invalidateSessionCallback();
        }
    });
}

- (void)invalidateAndCancel {
    if (_sharedSession) return;

    dispatch_sync(_workQueue, ^{
        self.invalidated = true;
    });

    for (YMURLSessionTask *task in _taskRegistry.allTasks) {
        [task cancel];
    }

    dispatch_async(_workQueue, ^{
        if (!self.delegate) return;
        [self.delegateQueue addOperationWithBlock:^{
            if ([self.delegate respondsToSelector:@selector(YMURLSession:didBecomeInvalidWithError:)]) {
                [self.delegate YMURLSession:self didBecomeInvalidWithError:nil];
            }
            self.delegate = nil;
        }];
    });
}

- (void)resetWithCompletionHandler:(void (^)(void))completionHandler {
    dispatch_queue_t globalQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(globalQ, ^{
        if (self.configuration.URLCache) {
            [self.configuration.URLCache removeAllCachedResponses];
        }

        NSURLCredentialStorage *storage = self.configuration.URLCredentialStorage;
        if (storage) {
            for (NSURLProtectionSpace *protectionSpace in storage.allCredentials) {
                NSDictionary *credentialEntry = storage.allCredentials[protectionSpace];
                for (NSURLCredential *credential in credentialEntry.allValues) {
                    [storage removeCredential:credential forProtectionSpace:protectionSpace];
                }
            }
        }
        [self flushWithCompletionHandler:completionHandler];
    });
}

- (void)flushWithCompletionHandler:(void (^)(void))completionHandler {
    if (completionHandler) {
        [_delegateQueue addOperationWithBlock:^{
            completionHandler();
        }];
    }
}

- (void)getAllTasksWithCompletionHandler:(void (^)(NSArray<__kindof YMURLSessionTask *> *_Nonnull))completionHandler {
    dispatch_async(_workQueue, ^{
        [self.delegateQueue addOperationWithBlock:^{
            NSMutableArray *tasks = [[NSMutableArray alloc] init];
            for (YMURLSessionTask *task in self.taskRegistry.allTasks) {
                if (task.state == YMURLSessionTaskStateRunning) {
                    [tasks addObject:task];
                }
            }
            if (completionHandler) completionHandler(tasks);
        }];
    });
}

- (YMURLSessionTask *)dataTaskWithURL:(NSURL *)url {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    return [self dataTaskWithRequest:url behaviour:b];
}

- (YMURLSessionTask *)dataTaskWithRequest:(NSURLRequest *)request {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    return [self dataTaskWithRequest:request behaviour:b];
}

- (YMURLSessionTaskBehaviour *)behaviourForTask:(YMURLSessionTask *)task {
    YMURLSessionTaskBehaviour *b = [_taskRegistry behaviourForTask:task];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        if (!(_delegate && [_delegate conformsToProtocol:@protocol(YMURLSessionTaskDelegate)])) {
            b.type = YMURLSessionTaskBehaviourTypeNoDelegate;
        }
    }
    return b;
}

- (void)addHandle:(YMEasyHandle *)handle {
    [_multiHandle addHandle:handle];
}

- (void)removeHandle:(YMEasyHandle *)handle {
    [_multiHandle removeHandle:handle];
}

#pragma mark - Private Methods

- (YMURLSessionTask *)dataTaskWithRequest:(id)request behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    if (_invalidated) {
        // TODO: throw
    }
    NSURLRequest *r = [self createConfiguredRequestFrom:request];
    NSUInteger i = [self createNextTaskIdentifier];
    YMURLSessionTask *task = [[YMURLSessionTask alloc] initWithSession:self reqeust:r taskIdentifier:i];
    dispatch_async(_workQueue, ^{
        [self.taskRegistry addWithTask:task behaviour:behaviour];
    });
    return task;
}

- (NSURLRequest *)createConfiguredRequestFrom:(id)request {
    NSURLRequest *r = nil;
    if ([request isKindOfClass:[NSURLRequest class]]) {
        r = [request copy];
    }

    if ([request isKindOfClass:[NSURL class]]) {
        r = [NSURLRequest requestWithURL:request];
    }
    [_configuration configureRequest:r];
    return r;
}

- (NSUInteger)createNextTaskIdentifier {
    dispatch_sync(_workQueue, ^{
        if (_nextTaskIdentifier == 0) _nextTaskIdentifier = 1;
        _nextTaskIdentifier += 1;
    });
    return _nextTaskIdentifier;
}

@end
