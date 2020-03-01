//
//  YMSessionConfiguration.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

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

- (NSURLRequest *)configureRequest:(NSURLRequest *)request {
    return [self setCookiesOnReqeust:request];
}

- (NSURLRequest *)setCookiesOnReqeust:(NSURLRequest *)request {
    NSMutableURLRequest *r = [request mutableCopy];
    if (_HTTPShouldSetCookies) {
        if (_HTTPCookieStorage && request.URL) {
            NSArray *cookies = [_HTTPCookieStorage cookiesForURL:request.URL];
            if (cookies) {
                NSDictionary *cookiesHeaderFields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
                NSString *cookieValue = cookiesHeaderFields[@"cookie"];
                if (cookieValue && cookieValue.length) {
                    [request setValue:cookieValue forKey:@"cookie"];
                }
            }
        }
    }
    return [r copy];
}

- (id)copyWithZone:(NSZone *)zone {
    YMURLSessionConfiguration *session = [[self.class alloc] init];
    session.requestCachePolicy = self.requestCachePolicy;
    session.timeoutIntervalForRequest = self.timeoutIntervalForRequest;
    session.timeoutIntervalForResource = self.timeoutIntervalForResource;
    session.allowsCellularAccess = self.allowsCellularAccess;
    session.HTTPShouldUsePipelining = self.HTTPShouldUsePipelining;
    session.HTTPShouldSetCookies = self.HTTPShouldSetCookies;
    session.HTTPCookieAcceptPolicy = self.HTTPShouldSetCookies;
    session.HTTPAdditionalHeaders = self.HTTPAdditionalHeaders;
    session.HTTPMaximumConnectionsPerHost = self.HTTPMaximumConnectionsPerHost;
    session.HTTPCookieStorage = self.HTTPCookieStorage;
    session.URLCredentialStorage = self.URLCredentialStorage;
    session.URLCache = self.URLCache;
    return session;
}

@end
