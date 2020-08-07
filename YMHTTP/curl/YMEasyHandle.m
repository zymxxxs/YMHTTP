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
        self.rawHandle = curl_easy_init();
        self.delegate = delegate;

        self.errorBuffer = (char *)malloc(sizeof(char) * (CURL_ERROR_SIZE + 1));
        memset(self.errorBuffer, 0, sizeof(char) * (CURL_ERROR_SIZE + 1));
        [self setupCallbacks];
    }
    return self;
}

- (void)dealloc {
    curl_easy_cleanup(self.rawHandle);
    curl_slist_free_all(_headerList);
    free(self.errorBuffer);
}

- (void)transferCompletedWithError:(NSError *)error {
    [self.delegate transferCompletedWithError:error];
}

- (void)resetTimer {
    // simply create a new timer with the same queue, timeout and handler
    // this must cancel the old handler and reset the timer
    self.timeoutTimer = [[YMTimeoutSource alloc] initWithQueue:self.timeoutTimer.queue
                                                  milliseconds:self.timeoutTimer.milliseconds
                                                       handler:self.timeoutTimer.handler];
}

- (void)setupCallbacks {
    // write
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_WRITEDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_WRITEFUNCTION, _curl_write_function));

    // read
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_READDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_READFUNCTION, _curl_read_function));

    // header
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_HEADERDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_HEADERFUNCTION, _curl_header_function));

    // socket options
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_SOCKOPTDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_SOCKOPTFUNCTION, _curl_socket_function));

    // seeking in input stream
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_SEEKDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_SEEKFUNCTION, _curl_seek_function));

    // progress
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_NOPROGRESS, 0));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_PROGRESSDATA, (__bridge void *)self));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_XFERINFOFUNCTION, _curl_XFERINFO_function));
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
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_VERBOSE, flag ? 1 : 0));
}

- (void)setDebugOutput:(BOOL)flag task:(YMURLSessionTask *)task {
    if (flag) {
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_DEBUGDATA, (__bridge void *)self));
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_DEBUGFUNCTION, _curl_debug_function));
    } else {
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_DEBUGDATA, NULL));
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_DEBUGFUNCTION, NULL));
    }
}

- (void)setPassHeadersToDataStream:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_HEADER, flag ? 1 : 0));
}

- (void)setFollowLocation:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_FOLLOWLOCATION, flag ? 1 : 0));
}

- (void)setProgressMeterOff:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_NOPROGRESS, flag ? 1 : 0));
}

- (void)setSkipAllSignalHandling:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_NOSIGNAL, flag ? 1 : 0));
}

- (void)setErrorBuffer:(char *)buffer {
    if (buffer != NULL) {
        _errorBuffer = buffer;
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_ERRORBUFFER, _errorBuffer));
    }
}

- (void)setFailOnHTTPErrorCode:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_FAILONERROR, flag ? 1 : 0));
}
- (void)setURL:(NSURL *)URL {
    _URL = URL;
    if (URL.absoluteString) {
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_URL, [URL.absoluteString UTF8String]));
    }
}

- (void)setConnectToHost:(NSString *)host port:(NSInteger)port {
    if (host) {
        NSString *originHost = self.URL.host;
        NSString *value = nil;
        if (port == 0) {
            value = [NSString stringWithFormat:@"%@::%@", originHost, host];
        } else {
            value = [NSString stringWithFormat:@"%@:%@:%@", originHost, @(port), host];
        }

        struct curl_slist *connect_to = NULL;
        connect_to = curl_slist_append(NULL, [value UTF8String]);
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_CONNECT_TO, connect_to));
    }
}

- (void)setSessionConfig:(YMURLSessionConfiguration *)config {
    self.config = config;
}

- (void)setAllowedProtocolsToHTTPAndHTTPS {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS));
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_REDIR_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS));
}

- (void)setPreferredReceiveBufferSize:(NSInteger)size {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_BUFFERSIZE, MIN(size, CURL_MAX_WRITE_SIZE)));
}

- (void)setCustomHeaders:(NSArray<NSString *> *)headers {
    for (NSString *header in headers) {
        _headerList = curl_slist_append(_headerList, [header UTF8String]);
    }
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_HTTPHEADER, _headerList));
}

- (void)setAutomaticBodyDecompression:(BOOL)flag {
    if (flag) {
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_ACCEPT_ENCODING, ""));
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_HTTP_CONTENT_DECODING, 1));
    } else {
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_ACCEPT_ENCODING, NULL));
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_HTTP_CONTENT_DECODING, 0));
    }
}

- (void)setRequestMethod:(NSString *)method {
    if ([method UTF8String] == NULL) return;
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_CUSTOMREQUEST, [method UTF8String]));
}

- (void)setNoBody:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_NOBODY, flag ? 1 : 0));
}

- (void)setUpload:(BOOL)flag {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_UPLOAD, flag ? 1 : 0));
}

- (void)setRequestBodyLength:(int64_t)length {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_INFILESIZE_LARGE, length));
}

- (void)setTimeout:(NSInteger)timeout {
    YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_TIMEOUT, (long)timeout));
}

- (void)setProxy {
    CFDictionaryRef dicRef = CFNetworkCopySystemProxySettings();
    const CFStringRef proxyString =
        (const CFStringRef)CFDictionaryGetValue(dicRef, (const void *)kCFNetworkProxiesHTTPProxy);
    const CFNumberRef portNum =
        (const CFNumberRef)CFDictionaryGetValue(dicRef, (const void *)kCFNetworkProxiesHTTPPort);

    NSNumber *port = (__bridge NSNumber *)portNum;
    NSString *proxy = (__bridge NSString *)proxyString;

    CFRelease(dicRef);

    if (proxy && port) {
        const char *ip = [proxy UTF8String];
        NSInteger p = [port longValue];
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_PROXY, ip));
        YM_ECODE(curl_easy_setopt(self.rawHandle, CURLOPT_PROXYPORT, p));
    }
}

- (void)updatePauseState:(YMEasyHandlePauseState)pauseState {
    NSUInteger send = pauseState & YMEasyHandlePauseStateSend;
    NSUInteger receive = pauseState & YMEasyHandlePauseStateReceive;
    int bitmask = 0 | (send ? CURLPAUSE_SEND : CURLPAUSE_SEND_CONT) | (receive ? CURLPAUSE_RECV : CURLPAUSE_RECV_CONT);
    int code = curl_easy_pause(self.rawHandle, bitmask);
    YM_ECODE(code);

    // https://curl.haxx.se/libcurl/c/curl_easy_pause.html
    // Starting in libcurl 7.32.0, unpausing a transfer will schedule a timeout trigger for that handle 1 millisecond
    // into the future, so that a curl_multi_socket_action( ... CURL_SOCKET_TIMEOUT) can be used immediately afterwards
    // to get the transfer going again as desired.
    if (bitmask == 0) {
        [self.delegate needTimeoutTimerToValue:0];
    }
}

- (double)getTimeoutIntervalSpent {
    double timeSpent;
    curl_easy_getinfo(self.rawHandle, CURLINFO_TOTAL_TIME, &timeSpent);
    return timeSpent / 1000;
}

- (long)connectFailureErrno {
    long _errno;
    YM_ECODE(curl_easy_getinfo(self.rawHandle, CURLINFO_OS_ERRNO, &_errno));
    return _errno;
}

- (void)pauseSend {
    if (self.pauseState & YMEasyHandlePauseStateSend) return;

    self.pauseState = self.pauseState | YMEasyHandlePauseStateSend;
    [self updatePauseState:self.pauseState];
}
- (void)unpauseSend {
    if (!(self.pauseState & YMEasyHandlePauseStateSend)) return;

    self.pauseState = self.pauseState ^ YMEasyHandlePauseStateSend;
    [self updatePauseState:self.pauseState];
}

- (void)pauseReceive {
    if (self.pauseState & YMEasyHandlePauseStateReceive) return;

    self.pauseState = self.pauseState | YMEasyHandlePauseStateReceive;
    [self updatePauseState:self.pauseState];
}

- (void)unpauseReceive {
    if (!(self.pauseState & YMEasyHandlePauseStateReceive)) return;

    self.pauseState = self.pauseState ^ YMEasyHandlePauseStateReceive;
    [self updatePauseState:self.pauseState];
}
#pragma mark - Private Methods

- (NSInteger)didReceiveData:(char *)data size:(NSInteger)size nmemb:(NSInteger)nmemb {
    NSData *buffer = [[NSData alloc] initWithBytes:data length:size * nmemb];
    if (![self.delegate respondsToSelector:@selector(didReceiveWithData:)]) return 0;

    YMEasyHandleAction action = [self.delegate didReceiveWithData:buffer];
    switch (action) {
        case YMEasyHandleActionProceed:
            return size * nmemb;
        case YMEasyHandleActionAbort:
            return 0;
        case YMEasyHandleActionPause:
            self.pauseState = self.pauseState | YMEasyHandlePauseStateReceive;
            return CURL_WRITEFUNC_PAUSE;
    }
    return 0;
}

- (NSInteger)didReceiveHeaderData:(char *)headerData
                             size:(NSInteger)size
                            nmemb:(NSInteger)nmemb
                    contentLength:(double)contentLength {
    NSData *buffer = [[NSData alloc] initWithBytes:headerData length:size * nmemb];

    [self setCookiesWithHeaderData:buffer];

    if (![self.delegate respondsToSelector:@selector(didReceiveWithHeaderData:contentLength:)]) {
        return 0;
    }

    YMEasyHandleAction action = [self.delegate didReceiveWithHeaderData:buffer contentLength:(int64_t)contentLength];
    switch (action) {
        case YMEasyHandleActionProceed:
            return size * nmemb;
        case YMEasyHandleActionAbort: {
            return 0;
        }
        case YMEasyHandleActionPause: {
            self.pauseState = self.pauseState | YMEasyHandlePauseStateReceive;
            return CURL_WRITEFUNC_PAUSE;
        }
    }
}

- (NSInteger)fillWriteBuffer:(char *)buffer size:(NSInteger)size nmemb:(NSInteger)nmemb {
    __block NSInteger d;
    [self.delegate fillWriteBufferLength:size * nmemb
                                  result:^(YMEasyHandleWriteBufferResult result, NSInteger length, NSData *data) {
                                      switch (result) {
                                          case YMEasyHandleWriteBufferResultPause:
                                              self.pauseState = self.pauseState | YMEasyHandlePauseStateSend;
                                              d = CURL_READFUNC_PAUSE;
                                              break;
                                          case YMEasyHandleWriteBufferResultAbort:
                                              d = CURL_READFUNC_ABORT;
                                              break;
                                          case YMEasyHandleWriteBufferResultBytes:
                                              memcpy(buffer, [data bytes], length);
                                              d = length;
                                              break;
                                      }
                                  }];

    return d;
}

- (int)seekInputStreamWithOffset:(int64_t)offset origin:(NSInteger)origin {
    if (origin != SEEK_SET) {
        YM_FATALERROR(@"Unexpected 'origin' in seek.");
    }

    BOOL r = [self.delegate seekInputStreamToPosition:offset];
    if (r) {
        return CURL_SEEKFUNC_OK;
    } else {
        return CURL_SEEKFUNC_CANTSEEK;
    }
}

- (void)setCookiesWithHeaderData:(NSData *)data {
    if (self.config && self.config.HTTPCookieAcceptPolicy != NSHTTPCookieAcceptPolicyNever &&
        self.config.HTTPCookieStorage) {
        NSString *headerLine = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (headerLine.length == 0) return;

        NSRange r = [headerLine rangeOfString:@":"];
        if (r.location != NSNotFound) {
            NSString *head = [headerLine substringToIndex:r.location];
            NSString *tail = [headerLine substringFromIndex:r.location + 1];

            NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            NSString *key = [head stringByTrimmingCharactersInSet:set];
            NSString *value = [tail stringByTrimmingCharactersInSet:set];

            if (key && value) {
                NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:@{key : value} forURL:self.URL];
                if ([cookies count] == 0) return;
                [self.config.HTTPCookieStorage setCookies:cookies forURL:self.URL mainDocumentURL:nil];
            }
        }
    }
}

#pragma mark - libcurl callbacks

NS_INLINE YMEasyHandle *from(void *userdata) {
    if (!userdata) return nil;
    return (__bridge YMEasyHandle *)userdata;
}

size_t _curl_write_function(char *data, size_t size, size_t nmemb, void *userdata) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;
    
    size_t code = [handle didReceiveData:data size:size nmemb:nmemb];
    [handle resetTimer];
    
    return code;
}

size_t _curl_read_function(char *data, size_t size, size_t nmemb, void *userdata) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;

    size_t code = [handle fillWriteBuffer:data size:size nmemb:nmemb];
    [handle resetTimer];
    
    return code;
}

size_t _curl_header_function(char *data, size_t size, size_t nmemb, void *userdata) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;

    double length;
    YM_ECODE(curl_easy_getinfo(handle.rawHandle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &length));
    size_t code = [handle didReceiveHeaderData:data size:size nmemb:nmemb contentLength:length];
    [handle resetTimer];
    return code;
}

int _curl_seek_function(void *userdata, curl_off_t offset, int origin) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return CURL_SEEKFUNC_FAIL;
    return [handle seekInputStreamWithOffset:offset origin:origin];
}

int _curl_XFERINFO_function(
    void *userdata, curl_off_t dltotal, curl_off_t dlnow, curl_off_t ultotal, curl_off_t ulnow) {
    YMEasyHandle *handle = from(userdata);
    if (!handle) return -1;
    [handle.delegate updateProgressMeterWithTotalBytesSent:ulnow
                                  totalBytesExpectedToSend:ultotal
                                        totalBytesReceived:dlnow
                               totalBytesExpectedToReceive:dltotal];
    return 0;
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
