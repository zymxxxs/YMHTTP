//
//  YMViewController.m
//  YMHTTP
//
//  Created by zymxxxs on 12/31/2019.
//  Copyright (c) 2019 zymxxxs. All rights reserved.
//

#import "YMViewController.h"
#import <YMHTTP/YMHTTP.h>
#import <CFNetwork/CFNetwork.h>

typedef NS_OPTIONS(NSUInteger, YMState) {
    YMStateReceive = 1 << 0,
    YMStateSend = 1 << 1
};

@interface YMViewController ()<YMURLSessionDataDelegate>

@property (nonatomic, strong) YMURLSession *s;

@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _s = [YMURLSession sessionWithConfiguration:[YMURLSessionConfiguration defaultSessionConfiguration]
                                                    delegate:self
                                               delegateQueue:nil];
//    YMURLSessionTask *d = [s dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]]];
//    [d resume];
    
    
//    [[self runWithURL:[NSURL URLWithString:@"https://httpbin.org/get"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://61.135.169.125"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://www.baidu.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    
    int i = 0;
    while (i<200) {
        [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
        [[self runWithURL:[NSURL URLWithString:@"http://www.baidu.com"]] resume];
        i++;
    }
    
//    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://61.135.169.125"]];
//    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//
//    }];
//    [task resume];
    
    
//    int a = 2;
//
//    switch (a) {
//        case 0:
//            NSLog(@"0");
//        case 1:
//            NSLog(@"1");
//        case 2:
//            NSLog(@"2");
//        case 3:
//            NSLog(@"3");
//
//        default:
//            break;
//    }
    
//    YMState state;
//
//    state = YMStateSend;
//    NSLog(@"%d", state & YMStateReceive);
//    state = YMStateSend | YMStateReceive;
//
//    NSLog(@"%d", state & YMStateReceive);
}



- (YMURLSessionTask *)runWithURL:(NSURL *)URL {
    
    NSMutableURLRequest *r = [[NSMutableURLRequest alloc] initWithURL:URL];
//    NSURL *b = [[NSBundle mainBundle] URLForResource:@"aaa" withExtension:@"txt"];
//    NSString *a = [NSString stringWithContentsOfURL:b
//                                           encoding:NSUTF8StringEncoding
//                                              error:nil];
//
//    r.HTTPBody = [a dataUsingEncoding:NSUTF8StringEncoding];
//    [r setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
//    r.HTTPBodyStream = [[NSInputStream alloc] initWithData:[a dataUsingEncoding:NSUTF8StringEncoding]];
    r.HTTPMethod = @"GET";
//    [r.HTTPBodyStream open];
    return [_s dataTaskWithRequest:r];
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"didCompleteWithError");
    NSLog(@"%@", task.response);
    NSLog(@"%@", error);
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData");
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}


- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
    NSLog(@"didReceiveResponse");
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        completionHandler(YMURLSessionResponseAllow);
//    });
}

//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
//    
//}



@end
