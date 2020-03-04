//
//  NSURLRequest+YMCategory.m
//  Pods
//
//  Created by zymxxxs on 2020/3/4.
//

#import <objc/runtime.h>
#import "NSURLRequest+YMCategory.h"

@implementation NSURLRequest (YMCategory)

+ (void)load {
    ym_swizzleMethods([self class], @selector(copyWithZone:), @selector(ym_copyWithZone:));
    ym_swizzleMethods([self class], @selector(mutableCopyWithZone:), @selector(ym_mutableCopyWithZone:));
}

NS_INLINE void ym_swizzleMethods(Class class, SEL origSel, SEL swizSel) {
    Method origMethod = class_getInstanceMethod(class, origSel);
    Method swizMethod = class_getInstanceMethod(class, swizSel);

    BOOL didAddMethod =
        class_addMethod(class, origSel, method_getImplementation(swizMethod), method_getTypeEncoding(swizMethod));
    if (didAddMethod) {
        class_replaceMethod(class, swizSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, swizMethod);
    }
}

- (instancetype)initWithURL:(NSURL *)URL connectToHost:(NSString *)connectToHost {
    return [self initWithURL:URL connectToHost:connectToHost connectToPort:0];
}

- (instancetype)initWithURL:(NSURL *)URL
              connectToHost:(NSString *)connectToHost
              connectToPort:(NSInteger)connectToPort {
    self = [self initWithURL:URL];
    if (self) {
        self.ym_connectToHost = connectToHost;
        self.ym_connectToPort = connectToPort;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL
              connectToHost:(NSString *)connectToHost
              connectToPort:(NSInteger)connectToPort
                cachePolicy:(NSURLRequestCachePolicy)cachePolicy
            timeoutInterval:(NSTimeInterval)timeoutInterval {
    self = [self initWithURL:URL cachePolicy:cachePolicy timeoutInterval:timeoutInterval];
    if (self) {
        self.ym_connectToHost = connectToHost;
        self.ym_connectToPort = connectToPort;
    }
    return self;
}

- (void)setYm_connectToHost:(NSString *_Nullable)ym_connectToHost {
    objc_setAssociatedObject(self, @selector(ym_connectToHost), ym_connectToHost, OBJC_ASSOCIATION_COPY);
}

- (NSString *)ym_connectToHost {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setYm_connectToPort:(NSInteger)ym_connectToPort {
    NSNumber *value = nil;
    if (ym_connectToPort <= 0) ym_connectToPort = 0;
    value = [NSNumber numberWithInteger:ym_connectToPort];

    objc_setAssociatedObject(self, @selector(ym_connectToPort), value, OBJC_ASSOCIATION_COPY);
}

- (NSInteger)ym_connectToPort {
    NSNumber *value = objc_getAssociatedObject(self, _cmd);
    if (!value) {
        return 0;
    }
    return [value integerValue];
}

- (id)ym_copyWithZone:(NSZone *)zone {
    NSURLRequest *r = [self ym_copyWithZone:zone];
    r.ym_connectToHost = self.ym_connectToHost;
    r.ym_connectToPort = self.ym_connectToPort;
    return r;
}

- (id)ym_mutableCopyWithZone:(NSZone *)zone {
    NSURLRequest *r = [self ym_mutableCopyWithZone:zone];
    r.ym_connectToHost = self.ym_connectToHost;
    r.ym_connectToPort = self.ym_connectToPort;
    return r;
}

@end
