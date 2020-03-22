//
//  YMEasyHandle.h
//  YMHTTP
//
//  Created by zymxxxs on 2019/12/31.
//

#import <Foundation/Foundation.h>

@class YMURLSessionConfiguration;
@class YMURLSessionTask;
@class YMTimeoutSource;

typedef NS_ENUM(NSUInteger, YMEasyHandleAction) {
    YMEasyHandleActionAbort,
    YMEasyHandleActionProceed,
    YMEasyHandleActionPause,
};
typedef NS_ENUM(NSUInteger, YMEasyHandleWriteBufferResult) {
    YMEasyHandleWriteBufferResultAbort,
    YMEasyHandleWriteBufferResultPause,
    YMEasyHandleWriteBufferResultBytes,
};

NS_ASSUME_NONNULL_BEGIN

@protocol YMEasyHandleDelegate <NSObject>

/// Handle data read from the network
- (YMEasyHandleAction)didReceiveWithData:(NSData *)data;

/// Handle header data read from the network
- (YMEasyHandleAction)didReceiveWithHeaderData:(NSData *)data contentLength:(int64_t)contentLength;

- (void)transferCompletedWithError:(NSError *)error;

- (void)fillWriteBufferLength:(NSInteger)length
                       result:(void (^)(YMEasyHandleWriteBufferResult result, NSInteger length, NSData *_Nullable data))
                                  result;

- (BOOL)seekInputStreamToPosition:(uint64_t)position;

- (void)needTimeoutTimerToValue:(NSInteger)value;

- (void)updateProgressMeterWithTotalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend totalBytesReceived:(int64_t)totalBytesReceived totalBytesExpectedToReceive:(int64_t)totalBytesExpectedToReceive;

@end

typedef void *YMURLSessionEasyHandle;

@interface YMEasyHandle : NSObject

@property (nonatomic, assign) YMURLSessionEasyHandle rawHandle;
@property (nonatomic, assign) char *errorBuffer;
@property (nullable, nonatomic, weak) id<YMEasyHandleDelegate> delegate;
@property (nullable, nonatomic, strong) YMTimeoutSource *timeoutTimer;
@property (nonatomic, strong) NSURL *URL;

- (instancetype)initWithDelegate:(id<YMEasyHandleDelegate>)delegate;

- (void)transferCompletedWithError:(nullable NSError *)error;

- (int)urlErrorCodeWithEasyCode:(int)easyCode;

- (void)setVerboseMode:(BOOL)flag;

/// - SeeAlso: https://curl.haxx.se/libcurl/c/CFURLSessionOptionDEBUGFUNCTION.html
- (void)setDebugOutput:(BOOL)flag task:(YMURLSessionTask *)task;

- (void)setPassHeadersToDataStream:(BOOL)flag;

/// Follow any Location: header that the server sends as part of a HTTP header in a 3xx response
- (void)setFollowLocation:(BOOL)flag;

/// Switch off the progress meter. It will also prevent the CFURLSessionOptionPROGRESSFUNCTION from getting called.
- (void)setProgressMeterOff:(BOOL)flag;

/// Skip all signal handling
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_NOSIGNAL.html
- (void)setSkipAllSignalHandling:(BOOL)flag;

/// Set error buffer for error messages
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_ERRORBUFFER.html
- (void)setErrorBuffer:(nullable char *)buffer;

/// Request failure on HTTP response >= 400
- (void)setFailOnHTTPErrorCode:(BOOL)flag;

/// URL to use in the request
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_URL.html
- (void)setURL:(NSURL *)URL;

- (void)setConnectToHost:(NSString *)host port:(NSInteger)port;

- (void)setSessionConfig:(YMURLSessionConfiguration *)config;

/// Set allowed protocols
///
/// - Note: This has security implications. Not limiting this, someone could
/// redirect a HTTP request into one of the many other protocols that libcurl
/// supports.
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_PROTOCOLS.html
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_REDIR_PROTOCOLS.html
- (void)setAllowedProtocolsToHTTPAndHTTPS;

/// set preferred receive buffer size
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_BUFFERSIZE.html
- (void)setPreferredReceiveBufferSize:(NSInteger)size;

/// Set custom HTTP headers
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_HTTPHEADER.html
- (void)setCustomHeaders:(NSArray<NSString *> *)headers;

- (void)setAutomaticBodyDecompression:(BOOL)flag;

/// Set request method
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_CUSTOMREQUEST.html
- (void)setRequestMethod:(NSString *)method;

/// Download request without body
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_NOBODY.html
- (void)setNoBody:(BOOL)flag;

/// Enable data upload
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_UPLOAD.html
- (void)setUpload:(BOOL)flag;

/// Set size of the request body to send
/// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_INFILESIZE_LARGE.html
- (void)setRequestBodyLength:(int64_t)length;

- (void)setTimeout:(NSInteger)timeout;

- (void)setProxy;

- (double)getTimeoutIntervalSpent;

- (void)pauseReceive;
- (void)unpauseReceive;


- (void)pauseSend;
- (void)unpauseSend;


@end

NS_ASSUME_NONNULL_END
