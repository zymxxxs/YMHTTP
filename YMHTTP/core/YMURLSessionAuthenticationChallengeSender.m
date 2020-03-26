//
//  YMURLSessionAuthenticationChallengeSender.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/16.
//

#import "YMURLSessionAuthenticationChallengeSender.h"

@implementation YMURLSessionAuthenticationChallengeSender

- (void)cancelAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge {
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge {
}

- (void)useCredential:(nonnull NSURLCredential *)credential
    forAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge {
}

@end
