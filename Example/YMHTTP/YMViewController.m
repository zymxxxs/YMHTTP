//
//  YMViewController.m
//  YMHTTP
//
//  Created by zymxxxs on 12/31/2019.
//  Copyright (c) 2019 zymxxxs. All rights reserved.
//

#import "YMViewController.h"
#import <YMHTTP/YMEasyHandle.h>
#import <YMHTTP/YMMultiHandle.h>
#import <YMHTTP/YMURLSessionConfiguration.h>
#import <YMHTTP/YMURLSession.h>
#import <YMHTTP/YMURLSessionTask.h>
#import <YMHTTP/YMMacro.h>
#import <YMHTTP/curl.h>
#import <CFNetwork/CFNetwork.h>

@interface YMViewController ()<YMURLSessionTaskDelegate, YMURLSessionDelegate>

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
    
    
    [[self runWithURL:[NSURL URLWithString:@"https://www.taobao.com/xxxx"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://www.baidu.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    
    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.taobao.com/xxxxx"]];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

    }];
    [task resume];

    
}



- (YMURLSessionTask *)runWithURL:(NSURL *)URL {
    return [_s dataTaskWithURL:URL];
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
}

//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
//    
//}



@end
