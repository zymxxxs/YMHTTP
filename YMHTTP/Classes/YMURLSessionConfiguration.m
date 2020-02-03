//
//  YMSessionConfiguration.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

// TODO: copy

#import "YMURLSessionConfiguration.h"

@implementation YMURLSessionConfiguration

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        _timeoutIntervalForRequest = 60;
        _timeoutIntervalForResource = 604800;
        _allowsCellularAccess = true;
        _HTTPShouldUsePipelining = false;
        _HTTPShouldSetCookies = true;
        _HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
        _HTTPAdditionalHeaders = nil;
        _HTTPMaximumConnectionsPerHost = 6;
        _HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        _URLCredentialStorage = [NSURLCredentialStorage sharedCredentialStorage];
        _URLCache = [NSURLCache sharedURLCache];
    }
    return self;
}

+ (YMURLSessionConfiguration *)defaultSessionConfiguration {
    return [[self alloc] init];
}

+ (YMURLSessionConfiguration *)configuration {
    return [self defaultSessionConfiguration];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[self.class alloc] init];
}

@end
