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
    static YMURLSession *_sharedSession = nil;
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
