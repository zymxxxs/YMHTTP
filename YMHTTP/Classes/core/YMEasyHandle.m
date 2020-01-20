//
//  YMEasyHandle.m
//  YMHTTP
//
//  Created by zymxxxs on 2019/12/31.
//

#import "YMEasyHandle.h"
#import "YMMacro.h"
#import "YMTimeoutSource.h"

@interface YMEasyHandle ()

@property (nonatomic, strong) YMTimeoutSource *timeoutTimer;

@end

@implementation YMEasyHandle

- (instancetype)initWithDelegate:(id<YMEasyHandleDelegate>)delegate
{
    self = [super init];
    if (self) {
        _rawHandle = curl_easy_init();
        _delegate = delegate;
        [self setupCallbacks];
        
        curl_easy_setopt(_rawHandle, CURLOPT_URL, "http://blog.csdn.net/JGood");
        curl_easy_perform(_rawHandle);
        NSLog(@"finish");
    }
    return self;
}

- (void)dealloc {
    curl_easy_cleanup(_rawHandle);
}

- (void)resetTimer {
    //simply create a new timer with the same queue, timeout and handler
    //this must cancel the old handler and reset the timer
    _timeoutTimer = [[YMTimeoutSource alloc] initWithQueue:_timeoutTimer.queue
                                              milliseconds:_timeoutTimer.milliseconds
                                                   handler:_timeoutTimer.handler];
}

- (void)setupCallbacks {

    // write
    curl_easy_setopt(_rawHandle, CURLOPT_WRITEDATA, (__bridge void *)self);
    curl_easy_setopt(_rawHandle, CURLOPT_WRITEFUNCTION, __curl_write_function);
    
    // read
    curl_easy_setopt(_rawHandle, CURLOPT_READDATA, (__bridge void *)self);
    curl_easy_setopt(_rawHandle, CURLOPT_READFUNCTION, __curl_read_function);
    
    // header
    curl_easy_setopt(_rawHandle, CURLOPT_HEADERDATA, (__bridge void *)self);
    curl_easy_setopt(_rawHandle, CURLOPT_HEADERFUNCTION, __curl_header_function);
    
    // socket options
    
}


# pragma mark - libcurl callback

NS_INLINE YMEasyHandle * from(void *userdata) {
    if (!userdata) return nil;
    return (__bridge YMEasyHandle *)userdata;
}

int __curl_write_function(char *data, size_t size, size_t nmemb, void *userdata) {
    NSLog(@"write %p", data);
    NSString *a = [[NSData dataWithBytes:data length:size] base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    NSLog(@"%@", a);
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;
    return 0;
}

int __curl_read_function(char *data, size_t size, size_t nmemb, void *userdata) {
    NSLog(@"read %p", data);
    NSString *a = [[NSData dataWithBytes:data length:size] base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    NSLog(@"%@", a);
    return 0;
}

int __curl_header_function(char *data, size_t size, size_t nmemb, void *userdata) {
    NSLog(@"header %p", data);
    NSString *a = [[NSData dataWithBytes:data length:size] base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    NSLog(@"%@", a);
    
    YMEasyHandle *handle = from(userdata);
    if (!handle) return 0;
    
    @YM_DEFER {
        [handle resetTimer];
    };
    
    double length;
    int r = curl_easy_getinfo(handle.rawHandle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &length);
    printf("%d", r);
    return 0;
}


/// - SeeAlso: <https://curl.haxx.se/libcurl/c/CURLOPT_HEADERFUNCTION.html>
- (int)didReceiveWithHeaderData:(void *)data
                           size:(int)size
                          nmerb:(int)nmerb
                  contentLength:(double)contentLength {
    
    NSData *buffer = [[NSData alloc] initWithBytes:data
                                            length:size*nmerb];
    
    // TODO: delegate
    return 0;
}

@end
