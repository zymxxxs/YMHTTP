//
//  YMURLSessionConfiguration.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YMURLSessionConfiguration : NSObject <NSCopying>

@property (class, readonly, strong) YMURLSessionConfiguration *defaultSessionConfiguration;

/// same to `defaultSessionConfiguration`
@property (class, readonly, strong) YMURLSessionConfiguration *configuration;

/// default cache policy for requests
@property NSURLRequestCachePolicy requestCachePolicy;

/// default timeout for requests.  This will cause a timeout if no data is transmitted for the given timeout value, and
/// is reset whenever data is transmitted.
@property NSTimeInterval timeoutIntervalForRequest;

/// default timeout for requests.  This will cause a timeout if a resource is not able to be retrieved within a given
/// timeout.
@property NSTimeInterval timeoutIntervalForResource;

/// Allow the use of HTTP pipelining
@property BOOL HTTPShouldUsePipelining;

/// Allow the session to set cookies on requests
@property BOOL HTTPShouldSetCookies;

/// Policy for accepting cookies.  This overrides the policy otherwise specified by the cookie storage.
@property NSHTTPCookieAcceptPolicy HTTPCookieAcceptPolicy;

/// Specifies additional headers which will be set on outgoing requests.
/// Note that these headers are added to the request only if not already present.
@property (nullable, copy) NSDictionary *HTTPAdditionalHeaders;

/// The maximum number of simultanous persistent connections per host
@property NSInteger HTTPMaximumConnectionsPerHost;

/// The cookie storage object to use, or nil to indicate that no cookies should be handled
@property (nullable, strong) NSHTTPCookieStorage *HTTPCookieStorage;

/// The credential storage object, or nil to indicate that no credential storage is to be used
@property (nullable, strong) NSURLCredentialStorage *URLCredentialStorage;

/// The URL resource cache, or nil to indicate that no caching is to be performed
@property (nullable, strong) NSURLCache *URLCache;

- (NSURLRequest *)configureRequest:(NSURLRequest *)request;

- (NSURLRequest *)configureRequestWithURL:(NSURL *)URL;

- (NSURLRequest *)setCookiesOnReqeust:(NSURLRequest *)request;

- (instancetype)init __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));
+ (instancetype)new __attribute__((unavailable(
    "Please use NSURLSessionConfiguration.defaultSessionConfiguration or other class methods to create instances")));

@end

NS_ASSUME_NONNULL_END
