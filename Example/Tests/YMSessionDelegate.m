//
//  YMSessionDelegate.m
//  YMHTTP_Tests
//
//  Created by zymxxxs on 2020/3/5.
//  Copyright © 2020 zymxxxs. All rights reserved.
//

#import "YMSessionDelegate.h"

@implementation YMSessionDelegate

- (void)YMURLSession:(YMURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [self.invalidateExpectation fulfill];
}

@end
