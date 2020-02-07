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
@property (nonatomic, strong) YMTaskRegistry *taskRegistry;

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
        _delegateQueue = [[NSOperationQueue alloc] init];
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
    return [self dataTaskWithRequest:url behaviour:nil];
}

- (YMURLSessionTask *)dataTaskWithRequest:(NSURLRequest *)request {
    return [self dataTaskWithRequest:request behaviour:nil];
}

#pragma mark - Private Methods

- (YMURLSessionTask *)dataTaskWithRequest:(id)request behaviour:(NSString *)behaviour {
    if (_invalidated) {
        // TODO: throw
    }
    NSURLRequest *r = [self createConfiguredRequestFrom:request];
    NSUInteger i = [self createNextTaskIdentifier];
    YMURLSessionTask *task = [[YMURLSessionTask alloc] initWithSession:self reqeust:r taskIdentifier:i];
    dispatch_async(_workQueue, ^{
        [self.taskRegistry addWithTask:task];
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
