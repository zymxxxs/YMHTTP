//
//  YMURLSession.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

#import "YMURLSession.h"
#import "YMMacro.h"
#import "YMMultiHandle.h"
#import "YMURLSessionConfiguration.h"

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

@end

@implementation YMURLSession

#pragma mark - Public Methods

- (instancetype)initWithConfiguration:(YMURLSessionConfiguration *)configuration
                             delegate:(id<NSURLSessionDelegate>)delegate
                        delegateQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
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
                                  delegate:(id<NSURLSessionDelegate>)delegate
                             delegateQueue:(NSOperationQueue *)queue {
    return [[YMURLSession alloc] initWithConfiguration:configuration delegate:delegate delegateQueue:queue];
}

+ (YMURLSession *)sessionWithConfiguration:(YMURLSessionConfiguration *)configuration {
    return [self sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
}

#pragma mark - Private Methods

@end
