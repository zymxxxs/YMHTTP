//
//  YMMultiHandle.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/1/3.
//

#import "YMMultiHandle.h"
#import "YMEasyHandle.h"
#import "YMTimeoutSource.h"

@interface YMMultiHandle ()

@property (nonatomic, strong) NSMutableArray<YMEasyHandle *> *easyHandles;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) YMTimeoutSource *timeoutSource;

@end

@implementation YMMultiHandle

- (instancetype)initWithWorkQueue:(dispatch_queue_t)workQueque {
    self = [super init];
    if (self) {
        _rawHandle = curl_multi_init();
        _easyHandles = [[NSMutableArray alloc] init];
        _queue = dispatch_queue_create_with_target("YMMutilHandle.isolation", DISPATCH_QUEUE_SERIAL, workQueque);
        [self setupCallbacks];
    }
    return self;
}

- (void)dealloc {
    [_easyHandles enumerateObjectsUsingBlock:^(YMEasyHandle *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        curl_multi_remove_handle(_rawHandle, obj.rawHandle);
    }];
    curl_multi_cleanup(_rawHandle);
}

- (void)setupCallbacks {
    // socket
    curl_multi_setopt(_rawHandle, CURLMOPT_SOCKETDATA, (__bridge void *)self);
    curl_multi_setopt(_rawHandle, CURLMOPT_SOCKETFUNCTION, _curlm_socket_function);

    // timeout
    curl_multi_setopt(_rawHandle, CURLMOPT_TIMERDATA, (__bridge void *)self);
    curl_multi_setopt(_rawHandle, CURLMOPT_TIMERFUNCTION, _curlm_timer_function);
}

- (int32_t)registerWithSocket:(curl_socket_t)socket what:(int)what socketSourcePtr:(void *)socketSourcePtr {
    // We get this callback whenever we need to register or unregister a
    // given socket with libdispatch.
    // The `action` / `what` defines if we should register or unregister
    // that we're interested in read and/or write readiness. We will do so
    // through libdispatch (DispatchSource) and store the source(s) inside
    // a `SocketSources` which we in turn store inside libcurl's multi handle
    // by means of curl_multi_assign() -- we retain the object fist.

    YMSocketRegisterAction *action = [[YMSocketRegisterAction alloc] initWithRawValue:what];
    YMSocketSources *socketSources = [YMSocketSources from:socketSourcePtr];

    if (socketSources == nil && action.needsSource) {
        YMSocketSources *s = [[YMSocketSources alloc] init];
        void *sp = (__bridge_retained void *)s;
        curl_multi_assign(_rawHandle, socket, sp);
        socketSources = s;
    } else if (socketSources != nil && action.type == YMSocketRegisterActionTypeUnregister) {
        YMSocketSources *s = (__bridge_transfer YMSocketSources *)socketSourcePtr;
        s = nil;
    }
    if (socketSources) {
        __weak typeof(self) _wself = self;
        [socketSources createSourcesWithAction:action
                                        socket:socket
                                         queue:_queue
                                       handler:^{
                                           [_wself performActionForSocket:socket];
                                       }];
    }

    return 0;
}

#pragma mark - Public Methods

- (void)addHandle:(YMEasyHandle *)handle {
    // If this is the first handle being added, we need to `kick` the
    // underlying multi handle by calling `timeoutTimerFired` as
    // described in
    // <https://curl.haxx.se/libcurl/c/curl_multi_socket_action.html>.
    // That will initiate the registration for timeout timer and socket
    // readiness.
    BOOL needsTimeout = false;
    if ([_easyHandles count] == 0) needsTimeout = YES;
    [_easyHandles addObject:handle];
    // TODO: Try catch
    curl_multi_add_handle(_rawHandle, handle.rawHandle);
    if (needsTimeout) [self timeoutTimerFired];
}

- (void)removeHandle:(YMEasyHandle *)handle {
    NSUInteger idx =
        [_easyHandles indexOfObjectPassingTest:^BOOL(YMEasyHandle *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if (obj.rawHandle == handle.rawHandle) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];

    if (idx == NSNotFound) {
        // TODO: throw error
    }

    [_easyHandles removeObjectAtIndex:idx];
    // TODO: Try catch
    curl_multi_remove_handle(_rawHandle, handle.rawHandle);
}

#pragma mark - libcurl callback

NS_INLINE YMMultiHandle *from(void *userdata) {
    if (!userdata) return nil;
    return (__bridge YMMultiHandle *)userdata;
}

int _curlm_socket_function(
    YMURLSessionEasyHandle easyHandle, curl_socket_t socket, int what, void *userdata, void *socketptr) {
    YMMultiHandle *handle = from(userdata);
    if (!handle) {
        NSException *e = nil;
        @throw e;
    }

    [handle registerWithSocket:socket what:what socketSourcePtr:socketptr];
    return 0;
}

int _curlm_timer_function(YMURLSessionEasyHandle easyHandle, int timeout, void *userdata) {
    YMMultiHandle *handle = from(userdata);
    if (!handle) {
        NSException *e = nil;
        @throw e;
    }
    [handle updateTimeoutTimerToValue:timeout];
    return 0;
}

#pragma mark - Primate Methods

- (void)performActionForSocket:(int)socket {
    // TODO: try catch
    [self readAndWriteAvailableDataOnSocket:socket];
}

- (void)timeoutTimerFired {
    // TODO: try catch
    [self readAndWriteAvailableDataOnSocket:CURL_SOCKET_TIMEOUT];
}

- (void)readAndWriteAvailableDataOnSocket:(int)socket {
    int runningHandlesCount = 0;
    curl_multi_socket_action(_rawHandle, socket, 0, &runningHandlesCount);
    [self readMessages];
}

/// Check the status of all individual transfers.
///
/// libcurl refers to this as “read multi stack informationals”.
/// Check for transfers that completed.
- (void)readMessages {
    while (true) {
        int count = 0;
        CURLMsg msg = mutilHandleInfoRead(_rawHandle, &count);
        if (!msg.easy_handle) break;
        YMURLSessionEasyHandle easyHandle = msg.easy_handle;
        int code = msg.data.result;
        [self completedTransferForEasyHandle:easyHandle easyCode:code];
    }
}

- (void)completedTransferForEasyHandle:(YMURLSessionEasyHandle)handle easyCode:(int)easyCode {
    NSUInteger idx =
        [_easyHandles indexOfObjectPassingTest:^BOOL(YMEasyHandle *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if (obj.rawHandle == handle) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];

    if (idx == NSNotFound) {
        // TODO: Transfer completed for easy handle, but it is not in the list of added handles.
    }
    YMEasyHandle *easyHandle = _easyHandles[idx];
    int errCode = [easyHandle urlErrorCodeWithEasyCode:easyCode];
    if (errCode != 0) {
    }
}

CURLMsg mutilHandleInfoRead(YMURLSessionMultiHandle handle, int *msgs_in_queue) {
    CURLMsg info = {};
    CURLMsg *msg = curl_multi_info_read(handle, msgs_in_queue);
    if (msg == NULL) return info;

    if (msg->msg != CURLMSG_DONE) return info;

    return *msg;
}

- (void)updateTimeoutTimerToValue:(int)value {
    //    A timeout_ms value of -1 passed to this callback means you should delete the timer. All other values are valid
    //    expire times in number of milliseconds.
    if (value == -1)
        _timeoutSource = nil;
    else if (value == 0) {
        _timeoutSource = nil;
        dispatch_async(_queue, ^{
            [self timeoutTimerFired];
        });
    } else {
        if (_timeoutSource == nil || _timeoutSource.milliseconds != value) {
            __weak typeof(self) _wself = self;
            _timeoutSource = [[YMTimeoutSource alloc] initWithQueue:_queue
                                                       milliseconds:value
                                                            handler:^{
                                                                [_wself timeoutTimerFired];
                                                            }];
        }
    }
}

@end

@implementation YMSocketRegisterAction

- (instancetype)initWithRawValue:(int)rawValue {
    self = [super init];
    if (self) {
        switch (rawValue) {
            case CURL_POLL_NONE:
                _type = YMSocketRegisterActionTypeNone;
                break;
            case CURL_POLL_IN:
                _type = YMSocketRegisterActionTypeRegisterRead;
                break;
            case CURL_POLL_OUT:
                _type = YMSocketRegisterActionTypeRegisterWrite;
                break;
            case CURL_POLL_INOUT:
                _type = YMSocketRegisterActionTypeRegisterReadAndWrite;
                break;
            case CURL_POLL_REMOVE:
                _type = YMSocketRegisterActionTypeUnregister;
                break;
            default:
                // TODO: throw a exception
                break;
        }
    }
    return self;
}

/// Should a libdispatch source be registered for **read** readiness?
- (BOOL)needsReadSource {
    switch (_type) {
        case YMSocketRegisterActionTypeNone:
            return false;
        case YMSocketRegisterActionTypeRegisterRead:
            return true;
        case YMSocketRegisterActionTypeRegisterWrite:
            return false;
        case YMSocketRegisterActionTypeRegisterReadAndWrite:
            return true;
        case YMSocketRegisterActionTypeUnregister:
            return false;
    }
}

/// Should a libdispatch source be registered for **write** readiness?
- (BOOL)needsWriteSource {
    switch (_type) {
        case YMSocketRegisterActionTypeNone:
            return false;
        case YMSocketRegisterActionTypeRegisterRead:
            return false;
        case YMSocketRegisterActionTypeRegisterWrite:
            return true;
        case YMSocketRegisterActionTypeRegisterReadAndWrite:
            return true;
        case YMSocketRegisterActionTypeUnregister:
            return false;
    }
}

/// Should either a **read** or a **write** readiness libdispatch source be
/// registered?
- (BOOL)needsSource {
    return self.needsReadSource || self.needsWriteSource;
}

@end

@implementation YMSocketSources

- (void)createSourcesWithAction:(YMSocketRegisterAction *)action
                         socket:(curl_socket_t)socket
                          queue:(dispatch_queue_t)queue
                        handler:(dispatch_block_t)handler {
    if (action.needsReadSource) {
        [self createReadSourceWithSocket:socket queue:queue handler:handler];
    }

    if (action.needsWriteSource) {
        [self createWriteSourceWithSocket:socket queue:queue handler:handler];
    }
}

- (void)createReadSourceWithSocket:(curl_socket_t)socket
                             queue:(dispatch_queue_t)queue
                           handler:(dispatch_block_t)handler {
    if (_readSource) return;

    dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, socket, 0, queue);
    dispatch_source_set_event_handler(s, handler);
    _readSource = s;
    dispatch_resume(s);
}

- (void)createWriteSourceWithSocket:(curl_socket_t)socket
                              queue:(dispatch_queue_t)queue
                            handler:(dispatch_block_t)handler {
    if (_writeSource) return;

    dispatch_source_t s = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, socket, 0, queue);
    dispatch_source_set_event_handler(s, handler);
    _writeSource = s;
    dispatch_resume(s);
}

- (void)tearDown {
    if (_readSource) {
        dispatch_source_cancel(_readSource);
    }
    _readSource = nil;

    if (_writeSource) {
        dispatch_source_cancel(_writeSource);
    }
    _writeSource = nil;
}

+ (instancetype)from:(void *)socketSourcePtr {
    if (!socketSourcePtr) return nil;
    return (__bridge YMSocketSources *)socketSourcePtr;
}

@end
