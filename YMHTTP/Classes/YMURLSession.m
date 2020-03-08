//
//  YMURLSession.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

#import "YMURLSession.h"
#import "NSURLRequest+YMCategory.h"
#import "YMMacro.h"
#import "YMMultiHandle.h"
#import "YMTaskRegistry.h"
#import "YMURLSessionConfiguration.h"
#import "YMURLSessionTask.h"
#import "YMURLSessionTaskBehaviour.h"
#import "YMURLSessionTaskBody.h"

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
@property (readwrite, strong) NSOperationQueue *delegateQueue;

@end

@implementation YMURLSession

#pragma mark - Public Methods

- (instancetype)initWithConfiguration:(YMURLSessionConfiguration *)configuration
                             delegate:(id<YMURLSessionDelegate>)delegate
                        delegateQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        self.taskRegistry = [[YMTaskRegistry alloc] init];
        ym_initializeLibcurl();
        self.identifier = nextSessionIdentifier();
        NSString *queueLabel = [NSString stringWithFormat:@"YMURLSession %@", @(self.identifier)];
        self.workQueue = dispatch_queue_create([queueLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        if (queue) {
            _delegateQueue = queue;
        } else {
            _delegateQueue = [[NSOperationQueue alloc] init];
        }
        _delegateQueue.maxConcurrentOperationCount = 1;
        self.delegate = delegate;
        _configuration = configuration;
        self.multiHandle = [[YMMultiHandle alloc] initWithConfiguration:_configuration WorkQueue:self.workQueue];
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
    dispatch_async(self.workQueue, ^{
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
    if (self == _sharedSession) return;

    dispatch_sync(self.workQueue, ^{
        self.invalidated = true;
    });

    for (YMURLSessionTask *task in self.taskRegistry.allTasks) {
        [task cancel];
    }

    dispatch_async(self.workQueue, ^{
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
    dispatch_async(self.workQueue, ^{
        [self.delegateQueue addOperationWithBlock:^{
            NSMutableArray *tasks = [[NSMutableArray alloc] init];
            for (YMURLSessionTask *task in self.taskRegistry.allTasks) {
                if (task.state == YMURLSessionTaskStateRunning || task.isSuspendedAfterResume) {
                    [tasks addObject:task];
                }
            }
            if (completionHandler) completionHandler(tasks);
        }];
    });
}

- (YMURLSessionTask *)taskWithURL:(NSURL *)url {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    return [self taskWithRequest:url behaviour:b];
}

- (YMURLSessionTask *)taskWithURL:(NSURL *)url connectToHost:(NSString *)host {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    NSURLRequest *r = [[NSURLRequest alloc] initWithURL:url connectToHost:host];
    return [self taskWithRequest:r behaviour:b];
}

- (YMURLSessionTask *)taskWithURL:(NSURL *)url connectToHost:(NSString *)host connectToPort:(NSInteger)port {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    NSURLRequest *r = [[NSURLRequest alloc] initWithURL:url connectToHost:host connectToPort:port];
    return [self taskWithRequest:r behaviour:b];
}

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    return [self taskWithRequest:request behaviour:b];
}

- (YMURLSessionTask *)taskWithURL:(NSURL *)url
                completionHandler:
                    (void (^)(NSData *_Nullable, NSHTTPURLResponse *_Nullable, NSError *_Nullable))completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    b.type = YMURLSessionTaskBehaviourTypeDataHandler;
    b.dataTaskCompeltion = completionHandler;
    return [self taskWithRequest:url behaviour:b];
}

- (YMURLSessionTask *)taskWithURL:(NSURL *)url
                    connectToHost:(NSString *)host
                completionHandler:
                    (void (^)(NSData *_Nullable, NSHTTPURLResponse *_Nullable, NSError *_Nullable))completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    b.type = YMURLSessionTaskBehaviourTypeDataHandler;
    b.dataTaskCompeltion = completionHandler;
    NSURLRequest *r = [[NSURLRequest alloc] initWithURL:url connectToHost:host];
    return [self taskWithRequest:r behaviour:b];
}

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                    completionHandler:(void (^)(NSData *_Nullable, NSHTTPURLResponse *_Nullable, NSError *_Nullable))
                                          completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    b.type = YMURLSessionTaskBehaviourTypeDataHandler;
    b.dataTaskCompeltion = completionHandler;
    return [self taskWithRequest:request behaviour:b];
}

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    b.type = YMURLSessionTaskBehaviourTypeTaskDelegate;
    YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithFileURL:fileURL];
    return [self taskWithRequest:request body:body behaviour:b];
}

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    b.type = YMURLSessionTaskBehaviourTypeTaskDelegate;
    YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithData:bodyData];
    return [self taskWithRequest:request body:body behaviour:b];
}

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                             fromData:(NSData *)bodyData
                    completionHandler:(void (^)(NSData *_Nullable, NSHTTPURLResponse *_Nullable, NSError *_Nullable))
                                          completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] initWithDataTaskCompeltion:completionHandler];
    YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithData:bodyData];
    return [self taskWithRequest:request body:body behaviour:b];
}

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                             fromFile:(NSURL *)fileURL
                    completionHandler:(void (^)(NSData *_Nullable, NSHTTPURLResponse *_Nullable, NSError *_Nullable))
                                          completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] initWithDataTaskCompeltion:completionHandler];
    YMURLSessionTaskBody *body = [[YMURLSessionTaskBody alloc] initWithFileURL:fileURL];
    return [self taskWithRequest:request body:body behaviour:b];
}

- (YMURLSessionTask *)taskWithStreamedRequest:(NSURLRequest *)request {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    b.type = YMURLSessionTaskBehaviourTypeTaskDelegate;
    return [self taskWithRequest:request body:nil behaviour:b];
}

- (YMURLSessionTask *)taskWithDownloadURL:(NSURL *)url {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    YMURLSessionTask *task = [self taskWithRequest:url behaviour:b];
    // TODO: this is ugly, need to fix it
    [task setValue:[NSNumber numberWithBool:true] forKey:@"isDownloadTask"];
    return task;
}

- (YMURLSessionTask *)taskWithDownloadRequest:(NSURLRequest *)request {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] init];
    YMURLSessionTask *task = [self taskWithRequest:request behaviour:b];
    [task setValue:[NSNumber numberWithBool:true] forKey:@"isDownloadTask"];
    return task;
}

- (YMURLSessionTask *)taskWithDownloadURL:(NSURL *)url
                        completionHandler:(void (^)(NSURL *_Nullable, NSHTTPURLResponse *_Nullable, NSError *_Nullable))
                                              completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] initWithDownloadTaskCompeltion:completionHandler];
    YMURLSessionTask *task = [self taskWithRequest:url behaviour:b];
    [task setValue:[NSNumber numberWithBool:true] forKey:@"isDownloadTask"];
    return task;
}

- (YMURLSessionTask *)taskWithDownloadRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURL *_Nullable,
                                                        NSHTTPURLResponse *_Nullable,
                                                        NSError *_Nullable))completionHandler {
    YMURLSessionTaskBehaviour *b = [[YMURLSessionTaskBehaviour alloc] initWithDownloadTaskCompeltion:completionHandler];
    YMURLSessionTask *task = [self taskWithRequest:request behaviour:b];
    [task setValue:[NSNumber numberWithBool:true] forKey:@"isDownloadTask"];
    return task;
}

- (YMURLSessionTaskBehaviour *)behaviourForTask:(YMURLSessionTask *)task {
    YMURLSessionTaskBehaviour *b = [_taskRegistry behaviourForTask:task];
    if (b.type == YMURLSessionTaskBehaviourTypeTaskDelegate) {
        if (!(self.delegate && [self.delegate conformsToProtocol:@protocol(YMURLSessionTaskDelegate)])) {
            b.type = YMURLSessionTaskBehaviourTypeNoDelegate;
        }
    }
    return b;
}

- (void)addHandle:(YMEasyHandle *)handle {
    [self.multiHandle addHandle:handle];
}

- (void)removeHandle:(YMEasyHandle *)handle {
    [self.multiHandle removeHandle:handle];
}

- (void)updateTimeoutTimerToValue:(NSInteger)value {
    [self.multiHandle updateTimeoutTimerToValue:value];
}

#pragma mark - Private Methods

- (YMURLSessionTask *)taskWithRequest:(id)request behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    if (self.invalidated) {
        YM_FATALERROR(@"Session invalidated");
    }
    NSURLRequest *r = [self createConfiguredRequestFrom:request];
    NSUInteger i = [self createNextTaskIdentifier];
    YMURLSessionTask *task = [[YMURLSessionTask alloc] initWithSession:self reqeust:r taskIdentifier:i];
    dispatch_async(self.workQueue, ^{
        [self.taskRegistry addWithTask:task behaviour:behaviour];
    });
    return task;
}

- (YMURLSessionTask *)taskWithRequest:(id)request
                                 body:(YMURLSessionTaskBody *)body
                            behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    if (self.invalidated) {
        YM_FATALERROR(@"Session invalidated");
    }
    NSURLRequest *r = [self createConfiguredRequestFrom:request];
    NSUInteger i = [self createNextTaskIdentifier];
    YMURLSessionTask *task = [[YMURLSessionTask alloc] initWithSession:self reqeust:r taskIdentifier:i body:body];
    dispatch_async(self.workQueue, ^{
        [self.taskRegistry addWithTask:task behaviour:behaviour];
    });
    return task;
}

- (NSURLRequest *)createConfiguredRequestFrom:(id)request {
    NSURLRequest *r = nil;
    if ([request isKindOfClass:[NSURLRequest class]]) {
        r = [_configuration configureRequest:request];
    }

    if ([request isKindOfClass:[NSURL class]]) {
        NSURL *URL = (NSURL *)request;
        r = [_configuration configureRequestWithURL:URL];
    }

    return r;
}

- (NSUInteger)createNextTaskIdentifier {
    dispatch_sync(self.workQueue, ^{
        if (self.nextTaskIdentifier == 0) self.nextTaskIdentifier = 1;
        self.nextTaskIdentifier += 1;
    });
    return self.nextTaskIdentifier;
}

@end
