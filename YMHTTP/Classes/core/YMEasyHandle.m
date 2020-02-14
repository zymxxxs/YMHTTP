//
//  YMEasyHandle.m
//  YMHTTP
//
//  Created by zymxxxs on 2019/12/31.
//

#import "YMEasyHandle.h"
#import "YMMacro.h"
#import "YMTimeoutSource.h"
#import "YMURLSessionConfiguration.h"
#import "YMURLSessionTask.h"
#import "curl.h"

typedef NS_OPTIONS(NSUInteger, YMEasyHandlePauseState) {
    YMEasyHandlePauseStateReceive = 1 << 0,
    YMEasyHandlePauseStateSend = 1 << 1
};

@interface YMEasyHandle ()

@property (nonatomic, strong) YMURLSessionConfiguration *config;
@property (nonatomic, assign) YMEasyHandlePauseState pauseState;

@end

@implementation YMEasyHandle {
    struct curl_slist *_headerList;
}

- (instancetype)initWithDelegate:(id<YMEasyHandleDelegate>)delegate {
    self = [super init];
    if (self) {
        _rawHandle = curl_easy_init();
        _delegate = delegate;
        _errorBuffer = (char *)malloc(sizeof(char) * (CURL_ERROR_SIZE + 1));
        memset(_errorBuffer, 0, sizeof(char) * (CURL_ERROR_SIZE + 1));
        [self setupCallbacks];
    }
    return self;
}

- (void)dealloc {
    curl_easy_cleanup(_rawHandle);
    curl_slist_free_all(_headerList);
}

- (void)transferCompletedWithError:(NSError *)error {
    [_delegate transferCompletedWithError:error];
}

- (void)resetTimer {
    // simply create a new timer with the same queue, timeout and handler
    // this must cancel the old handler and reset the timer
    _timeoutTimer = [[YMTimeoutSource alloc] initWithQueue:_timeoutTimer.queue
                                              milliseconds:_timeoutTimer.milliseconds
                                                   handler:_timeoutTimer.handler];
}

- (void)setupCallbacks {
    // write
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_WRITEDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_WRITEFUNCTION, _curl_write_function));

    // read
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_READDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_READFUNCTION, _curl_read_function));

    // header
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_HEADERDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_HEADERFUNCTION, _curl_header_function));

    // socket options
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_SOCKOPTDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_SOCKOPTFUNCTION, _curl_socket_function));
}

#pragma mark - Public Methods
- (int)urlErrorCodeWithEasyCode:(int)easyCode {
    int failureErrno = (int)[self connectFailureErrno];
    if (easyCode == CURLE_OK) {
        return 0;
    } else if (failureErrno == ECONNREFUSED) {
        return NSURLErrorCannotConnectToHost;
    } else if (easyCode == CURLE_UNSUPPORTED_PROTOCOL) {
        return NSURLErrorUnsupportedURL;
    } else if (easyCode == CURLE_URL_MALFORMAT) {
        return NSURLErrorBadURL;
    } else if (easyCode == CURLE_COULDNT_RESOLVE_HOST) {
        return NSURLErrorCannotFindHost;
    } else if (easyCode == CURLE_RECV_ERROR && failureErrno == ECONNRESET) {
        return NSURLErrorNetworkConnectionLost;
    } else if (easyCode == CURLE_SEND_ERROR && failureErrno == ECONNRESET) {
        return NSURLErrorNetworkConnectionLost;
    } else if (easyCode == CURLE_GOT_NOTHING) {
        return NSURLErrorBadServerResponse;
    } else if (easyCode == CURLE_ABORTED_BY_CALLBACK) {
        return NSURLErrorUnknown;
    } else if (easyCode == CURLE_COULDNT_CONNECT && failureErrno == ETIMEDOUT) {
        return NSURLErrorTimedOut;
    } else if (easyCode == CURLE_OPERATION_TIMEDOUT) {
        return NSURLErrorTimedOut;
    } else {
        return NSURLErrorUnknown;
    }
}

- (void)setVerboseMode:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_VERBOSE, flag ? 1 : 0));
}

- (void)setDebugOutput:(BOOL)flag task:(YMURLSessionTask *)task {
    if (flag) {
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGDATA, (__bridge void *)self));
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGFUNCTION, _curl_debug_function));
    } else {
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGDATA, NULL));
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGFUNCTION, NULL));
    }
}

- (void)setPassHeadersToDataStream:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_HEADER, flag ? 1 : 0));
}

- (void)setFollowLocation:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_FOLLOWLOCATION, flag ? 1 : 0));
}

- (void)setProgressMeterOff:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_NOPROGRESS, flag ? 1 : 0));
}

- (void)setSkipAllSignalHandling:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_NOSIGNAL, flag ? 1 : 0));
}

- (void)setErrorBuffer:(char *)buffer {
    char *b = buffer ?: _errorBuffer;
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_ERRORBUFFER, b));
}

- (void)setFailOnHTTPErrorCode:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_FAILONERROR, flag ? 1 : 0));
}
- (void)setURL:(NSURL *)URL {
    if (URL.absoluteString) {
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_URL, [URL.absoluteString UTF8String]));
    }
}

- (void)setSessionConfig:(YMURLSessionConfiguration *)config {
    _config = config;
}

- (void)setAllowedProtocolsToHTTPAndHTTPS {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS));
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_REDIR_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS));
}

- (void)setPreferredReceiveBufferSize:(NSInteger)size {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_BUFFERSIZE, MIN(size, CURL_MAX_WRITE_SIZE)));
}

- (void)setCustomHeaders:(NSArray<NSString *> *)headers {
    for (NSString *header in headers) {
        _headerList = curl_slist_append(_headerList, [header UTF8String]);
    }
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_HTTPHEADER, _headerList));
}

- (void)setAutomaticBodyDecompression:(BOOL)flag {
    if (flag) {
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_ACCEPT_ENCODING, ""));
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_HTTP_CONTENT_DECODING, 1));
    } else {
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_ACCEPT_ENCODING, NULL));
        YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_HTTP_CONTENT_DECODING, 0));
    }
}

- (void)setRequestMethod:(NSString *)method {
    if ([method UTF8String] == NULL) return;
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_CUSTOMREQUEST, [method UTF8String]));
}

- (void)setNoBody:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_NOBODY, flag ? 1 : 0));
}

- (void)setUpload:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_UPLOAD, flag ? 1 : 0));
}

- (void)setRequestBodyLength:(int64_t)length {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_INFILESIZE_LARGE, length));
}

- (void)setTimeout:(NSInteger)timeout {
    YM_ECODE(curl_easy_setopt(_rawHandle, CURLOPT_TIMEOUT, (long)timeout));
}

- (double)getTimeoutIntervalSpent {
    double timeSpent;
    curl_easy_getinfo(_rawHandle, CURLINFO_TOTAL_TIME, &timeSpent);
    return timeSpent / 1000;
}

- (long)connectFailureErrno {
    long _errno;
    YM_ECODE(curl_easy_getinfo(_rawHandle, CURLINFO_OS_ERRNO, &_errno));
    return _errno;
}

#pragma mark - Private Methods

- (NSInteger)didReceiveData:(char *)data size:(NSInteger)size nmemb:(NSInteger)nmemb {
    NSData *buffer = [[NSData alloc] initWithBytes:data length:size * nmemb];
    if (![_delegate respondsToSelector:@selector(didReceiveWithData:)]) return 0;

    YMEasyHandleAction action = [_delegate didReceiveWithData:buffer];
    switch (action) {
        case YMEasyHandleActionProceed:
            return size * nmemb;
        case YMEasyHandleActionAbort:
            return 0;
        case YMEasyHandleActionPause:
            _pauseState = _pauseState | YMEasyHandlePauseStateReceive;
            return CURL_WRITEFUNC_PAUSE;
    }
    return 0;
}

- (NSInteger)didReceiveHeaderData:(char *)headerData
                             size:(size_t)size
                            nmemb:(size_t)nmemb
                    contentLength:(double)contentLength {
    NSData *buffer = [[NSData alloc] initWithBytes:headerData length:size * nmemb];
    // TODO: setCookies

    if (![_delegate respondsToSelector:@selector(didReceiveWithHeaderData:contentLength:)]) {
        return 0;
    }

    YMEasyHandleAction action = [_delegate didReceiveWithHeaderData:buffer contentLength:(int64_t)contentLength];
    switch (action) {
        case YMEasyHandleActionProceed:
            return size * nmemb;
        case YMEasyHandleActionAbort: {
            _pauseState = _pauseState | YMEasyHandlePauseStateReceive;
            return 0;
        }
        case YMEasyHandleActionPause:
            return CURL_WRITEFUNC_PAUSE;
    }
    return 0;
}

#pragma mark - libcurl callbacks

NS_INLINE YMEasyHandle *from(void *userdata) {
    if (!userdata) return nil;
    return (__bridge YMEasyHandle *)userdata;
}

size_t _curl_write_function(char *data, size_t size, size_t nmemb, void *userdata) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;

    @YM_DEFER {
        [handle resetTimer];
    };

    return [handle didReceiveData:data size:size nmemb:nmemb];
}

size_t _curl_read_function(char *data, size_t size, size_t nmemb, void *userdata) {
    NSLog(@"read %p", data);
    NSString *a = [[NSData dataWithBytes:data length:size]
        base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    NSLog(@"%@", a);
    return 0;
}

size_t _curl_header_function(char *data, size_t size, size_t nmemb, void *userdata) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;

    @YM_DEFER {
        [handle resetTimer];
    };

    double length;
    YM_ECODE(curl_easy_getinfo(handle.rawHandle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &length));
    return [handle didReceiveHeaderData:data size:size nmemb:nmemb contentLength:length];
}

int _curl_debug_function(CURL *handle, curl_infotype type, char *data, size_t size, void *userptr) {
    NSString *text = @"";
    if (data) {
        text = [NSString stringWithUTF8String:data];
    }
    if (!userptr) return 0;
    YMURLSessionTask *task = (__bridge YMURLSessionTask *)userptr;
    // TODO: CFURLSessionInfo
    NSLog(@"%@ %@ %@", @(task.taskIdentifier), @(type), text);
    return 0;
}

int _curl_socket_function(void *userdata, curl_socket_t fd, curlsocktype type) { return 0; }

@end
