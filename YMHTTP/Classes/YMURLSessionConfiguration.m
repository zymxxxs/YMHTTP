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
        self.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        self.timeoutIntervalForRequest = 60;
        self.timeoutIntervalForResource = 604800;
        self.HTTPShouldUsePipelining = false;
        self.HTTPShouldSetCookies = true;
        self.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
        self.HTTPAdditionalHeaders = nil;
        self.HTTPMaximumConnectionsPerHost = 6;
        self.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        self.URLCredentialStorage = [NSURLCredentialStorage sharedCredentialStorage];
        self.URLCache = [NSURLCache sharedURLCache];
    }
    return self;
}

+ (YMURLSessionConfiguration *)defaultSessionConfiguration {
    return [[self alloc] init];
}

+ (YMURLSessionConfiguration *)configuration {
    return [self defaultSessionConfiguration];
}

- (NSURLRequest *)configureRequestWithURL:(NSURL *)URL {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:URL];
    r.cachePolicy = self.requestCachePolicy;
    r.timeoutInterval = self.timeoutIntervalForRequest;
    r.HTTPShouldUsePipelining = self.HTTPShouldUsePipelining;
    r.HTTPShouldHandleCookies = self.HTTPShouldSetCookies;
    return [self setCookiesOnReqeust:r];
}

- (NSURLRequest *)configureRequest:(NSURLRequest *)request {
    return [self setCookiesOnReqeust:request];
}

- (NSURLRequest *)setCookiesOnReqeust:(NSURLRequest *)request {
    NSMutableURLRequest *r = [request mutableCopy];
    if (self.HTTPShouldSetCookies) {
        if (self.HTTPCookieStorage && request.URL) {
            NSArray *cookies = [_HTTPCookieStorage cookiesForURL:request.URL];
            if (cookies && cookies.count) {
                NSDictionary *cookiesHeaderFields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
                NSString *cookieValue = cookiesHeaderFields[@"Cookie"];
                if (cookieValue && cookieValue.length) {
                    [r setValue:cookieValue forHTTPHeaderField:@"Cookie"];
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
