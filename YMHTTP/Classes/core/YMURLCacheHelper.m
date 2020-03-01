//
//  YMCacheHelper.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/28.
//

#import "YMURLCacheHelper.h"
#import "NSArray+YMCategory.h"

@implementation YMURLCacheHelper

NS_INLINE NSDateFormatter *dateFormatter() {
    static NSDateFormatter *_df;
    if (!_df) {
        _df = [[NSDateFormatter alloc] init];
        _df.locale = [NSLocale systemLocale];
        _df.dateFormat = @"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz";
    }
    return _df;
}

NS_INLINE NSString *parseArgumentPart(NSString *part, NSString *name) {
    NSString *prefix = [NSString stringWithFormat:@"%@=", name];
    if ([part hasPrefix:prefix]) {
        NSArray *split = [part componentsSeparatedByString:@"="];
        if (split && [split count] == 2) {
            NSString *argument = split[1];
            if ([argument hasPrefix:@"\""] && [argument hasSuffix:@"\""]) {
                if ([argument length] >= 2) {
                    NSRange range = NSMakeRange(1, [argument length] - 2);
                    argument = [argument substringWithRange:range];
                    return argument;
                } else
                    return 0;
            } else {
                return argument;
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
        expirationStart = [dateFormatter() dateFromString:dateString];
    } else {
        // TODO: maybe date is null
        NSLog(@"--------------------no date header");
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
        __block BOOL maxAge;
        __block BOOL sharedMaxAge;
        __block BOOL noCache = false;
        __block BOOL noStore = false;
        [self getCacheControlDeirectivesFromHeaderValue:cacheControl
                                             completion:^(NSString *maxAgeValue,
                                                          NSString *sharedMaxAgeValue,
                                                          BOOL noCacheValue,
                                                          BOOL noStoreValue) {
                                                 maxAge = maxAgeValue ? true : false;
                                                 sharedMaxAge = sharedMaxAgeValue ? true : false;
                                                 noCache = noCacheValue;
                                                 noStore = noStoreValue;
                                             }];

        if (maxAge) {
            hasMaxAge = true;

            NSDate *expiration = [expirationStart dateByAddingTimeInterval:maxAge];
            NSComparisonResult result = [expiration compare:now];
            if (result == NSOrderedDescending) return false;
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
        NSDate *expiration = [dateFormatter() dateFromString:expires];
        if (!expiration) return false;

        NSComparisonResult result = [now compare:expiration];
        if (NSOrderedAscending == result || NSOrderedSame == result) {
            return false;
        }
    }

    return true;
}

+ (void)getCacheControlDeirectivesFromHeaderValue:(NSString *)headerValue
                                       completion:(void (^)(NSString *maxAge,
                                                            NSString *sharedMaxAge,
                                                            BOOL noCache,
                                                            BOOL noStore))completion {
    __block NSString *maxAge;
    __block NSString *sharedMaxAge;
    __block BOOL noCache = false;
    __block BOOL noStore = false;

    [[headerValue componentsSeparatedByString:@","]
        enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            NSString *part = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            part = [part lowercaseStringWithLocale:[NSLocale systemLocale]];
            if ([part isEqualToString:@"no-cache"]) {
                noCache = true;
            } else if ([part isEqualToString:@"no-store"]) {
                noStore = true;
            } else if ([part containsString:@"max-age"]) {
                maxAge = parseArgumentPart(part, @"max-age");
            } else if ([part containsString:@"s-maxage"]) {
                sharedMaxAge = parseArgumentPart(part, @"s-maxage");
            }
        }];
    completion(maxAge, sharedMaxAge, noCache, noStore);
}

@end
