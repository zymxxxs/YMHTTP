//
//  YMCacheHelper.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/28.
//

#import "YMURLCacheHelper.h"
#import "NSArray+YMCategory.h"

@implementation YMURLCacheHelper

NS_INLINE NSDate *dateFromString(NSString *v) {
    // https://tools.ietf.org/html/rfc2616#section-3.3.1

    static NSDateFormatter *df;
    if (!df) {
        df = [[NSDateFormatter alloc] init];
    }

    // RFC 822
    df.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
    NSDate *d1 = [df dateFromString:v];
    if (d1) return d1;

    // RFC 850
    df.dateFormat = @"EEEE, dd-MMM-yy HH:mm:ss zzz";
    NSDate *d2 = [df dateFromString:v];
    if (d2) return d2;

    // ANSI C's asctime() format
    df.dateFormat = @"EEE MMM dd HH:mm:ss yy";
    NSDate *d3 = [df dateFromString:v];
    if (d3) return d3;

    return nil;
}

NS_INLINE NSInteger parseArgumentPart(NSString *part, NSString *name) {
    NSString *prefix = [NSString stringWithFormat:@"%@=", name];
    if ([part hasPrefix:prefix]) {
        NSArray *split = [part componentsSeparatedByString:@"="];
        if (split && [split count] == 2) {
            NSString *argument = split[1];
            if ([argument hasPrefix:@"\""] && [argument hasSuffix:@"\""]) {
                if ([argument length] >= 2) {
                    NSRange range = NSMakeRange(1, [argument length] - 2);
                    argument = [argument substringWithRange:range];
                    return [argument integerValue];
                } else
                    return 0;
            } else {
                return [argument integerValue];
            }
        }
    }
    return 0;
}

+ (BOOL)canCacheResponse:(NSCachedURLResponse *)response request:(NSURLRequest *)request {
    NSURLRequest *httpRequest = request;
    if (!httpRequest) return false;

    NSHTTPURLResponse *httpResponse = nil;
    if ([response.response isKindOfClass:[NSHTTPURLResponse class]]) {
        httpResponse = (NSHTTPURLResponse *)response.response;
    }
    if (!httpResponse) return false;

    // HTTP status codes: https://tools.ietf.org/html/rfc7231#section-6.1
    switch (httpResponse.statusCode) {
        case 200:
        case 203:
        case 204:
        case 206:
        case 300:
        case 301:
        case 404:
        case 405:
        case 410:
        case 414:
        case 501:
            break;

        default:
            return false;
    }

    if (httpResponse.allHeaderFields[@"Vary"] != nil) {
        return false;
    }

    NSDate *now = [NSDate date];
    NSDate *expirationStart;

    NSString *dateString = httpResponse.allHeaderFields[@"Date"];
    if (dateString) {
        expirationStart = dateFromString(dateString);
    } else {
        // TODO: maybe date is null, return false
        // 暂时这么处理
        NSLog(@"--------------------the header field Date is null------------------");
        return false;
    }

    if (httpResponse.allHeaderFields[@"WWW-Authenticate"] || httpResponse.allHeaderFields[@"Proxy-Authenticate"] ||
        httpResponse.allHeaderFields[@"Authorization"] || httpResponse.allHeaderFields[@"Proxy-Authorization"]) {
        return false;
    }

    // HTTP Methods: https://tools.ietf.org/html/rfc7231#section-4.2.3
    if ([httpRequest.HTTPMethod isEqualToString:@"GET"]) {
    } else if ([httpRequest.HTTPMethod isEqualToString:@"HEAD"]) {
        if (response.data && response.data.length > 0) {
            return false;
        }
    } else {
        return false;
    }

    // Cache-Control: https://tools.ietf.org/html/rfc7234#section-5.2
    BOOL hasCacheControl = false;
    BOOL hasMaxAge = false;
    NSString *cacheControl = httpResponse.allHeaderFields[@"cache-control"];
    if (cacheControl) {
        NSInteger maxAge = 0;
        NSInteger sharedMaxAge;
        BOOL noCache = false;
        BOOL noStore = false;

        [self getCacheControlDeirectivesFromHeaderValue:cacheControl
                                                 maxAge:&maxAge
                                           sharedMaxAge:&sharedMaxAge
                                                noCache:&noCache
                                                noStore:&noStore];

        if (maxAge > 0) {
            hasMaxAge = true;

            NSDate *expiration = [expirationStart dateByAddingTimeInterval:maxAge];
            if ([now timeIntervalSince1970] >= [expiration timeIntervalSince1970]) {
                return false;
            }
        }

        if (sharedMaxAge) hasMaxAge = true;
        hasCacheControl = true;
    }

    NSString *pragma = httpResponse.allHeaderFields[@"pragma"];
    if (!hasCacheControl && pragma) {
        NSArray *components = [pragma componentsSeparatedByString:@","];
        components = [components ym_map:^id _Nonnull(NSString *_Nonnull obj) {
            NSString *part = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            part = [part lowercaseStringWithLocale:[NSLocale systemLocale]];
            return part;
        }];
        if ([components containsObject:@"no-cache"]) {
            return false;
        }
    }

    NSString *expires = httpResponse.allHeaderFields[@"Expires"];
    if (!hasMaxAge && expires) {
        NSDate *expiration = dateFromString(expires);
        if (!expiration) return false;

        if ([now timeIntervalSince1970] >= [expiration timeIntervalSince1970]) {
            return false;
        }
    }

    return true;
}
+ (void)getCacheControlDeirectivesFromHeaderValue:(NSString *)headerValue
                                           maxAge:(NSInteger *)maxAge
                                     sharedMaxAge:(NSInteger *)sharedMaxAge
                                          noCache:(BOOL *)noCache
                                          noStore:(BOOL *)noStore {
    NSArray *components = [headerValue componentsSeparatedByString:@","];
    for (NSString *obj in components) {
        NSString *part = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        part = [part lowercaseStringWithLocale:[NSLocale systemLocale]];
        if ([part isEqualToString:@"no-cache"]) {
            *noCache = true;
        } else if ([part isEqualToString:@"no-store"]) {
            *noStore = true;
        } else if ([part containsString:@"max-age"]) {
            *maxAge = parseArgumentPart(part, @"max-age");
        } else if ([part containsString:@"s-maxage"]) {
            *sharedMaxAge = parseArgumentPart(part, @"s-maxage");
        }
    }
}

@end
