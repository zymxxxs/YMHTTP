//
//  YMViewController.m
//  YMHTTP
//
//  Created by zymxxxs on 12/31/2019.
//  Copyright (c) 2019 zymxxxs. All rights reserved.
//

#import "YMViewController.h"
#import <YMHTTP/YMHTTP.h>

@interface YMViewController ()

@property (nonatomic, strong) NSURLSession *us;
@property (nonatomic, strong) YMURLSession *yus;


@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

//
//    NSURLRequest *r1 = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://httpbin.org/get?a=b"]];
//    dispatch_group_t group2 = dispatch_group_create();
//    CFAbsoluteTime startYMURLSession = CFAbsoluteTimeGetCurrent();
//    for (int i=0; i<10; i++) {
//        dispatch_group_enter(group2);
//        [[[YMURLSession sharedSession] taskWithRequest:r1
//                                     completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
//            if (error) {
//                NSLog(@"YMURLSession 失败了");
//            }
//            dispatch_group_leave(group2);
//        }] resume];
//    }
//
//    dispatch_group_notify(group2, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        CFAbsoluteTime endYMURLSession = CFAbsoluteTimeGetCurrent();
//        NSLog(@"YMURLSession 总共花费时间：%@", @(endYMURLSession -  startYMURLSession));
//    });
//
//
//    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://httpbin.org/get"]];
//    dispatch_group_t group1 = dispatch_group_create();
//    CFAbsoluteTime startNSURLSession = CFAbsoluteTimeGetCurrent();
//    for (int i=0; i<10; i++) {
//        dispatch_group_enter(group1);
//        [[[NSURLSession sharedSession] dataTaskWithRequest:r
//                                         completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//            if (error) {
//                NSLog(@"NSURLSession 失败了");
//            }
//            dispatch_group_leave(group1);
//
//        }] resume];
//    }
//
//    dispatch_group_notify(group1, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        CFAbsoluteTime endNSURLSession = CFAbsoluteTimeGetCurrent();
//        NSLog(@"NSURLSession 总共花费时间：%@", @(endNSURLSession -  startNSURLSession));
//    });
}


@end
