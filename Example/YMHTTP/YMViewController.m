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
#import <CFNetwork/CFNetwork.h>

@interface YMViewController ()<YMURLSessionTaskDelegate, YMURLSessionDelegate>

@property (nonatomic, strong) YMMultiHandle *mh;

@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    YMURLSession *s = [YMURLSession sessionWithConfiguration:[YMURLSession sharedSession].configuration
                                                    delegate:self
                                               delegateQueue:nil];
    YMURLSessionTask *d = [s dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.github.com"]]];
    [d resume];
    
//    [d resume];
//    [d suspend];
//    [d suspend];
//    [d suspend];
//    [d resume];
//    [d resume];
//    [d resume];
//    [d resume];
//    [[s dataTaskWithURL:[NSURL URLWithString:@"https://www.baidu.com"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//
//    }] resume];


}

//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable))completionHandler {
//    
//}

@end
