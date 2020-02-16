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

@interface YMViewController ()<YMURLSessionDelegate>

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
    
    
    [[self runWithURL:[NSURL URLWithString:@"https://httpbin.org/get"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://www.baidu.com"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
//    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    
    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://httpbin.org/post"]];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

    }];
    [task resume];
    
    BOOL bb = [self conformsToProtocol:@protocol(YMURLSessionDelegate)];

    
    int a = 2;
    
    switch (a) {
        case 0:
            NSLog(@"0");
        case 1:
            NSLog(@"1");
        case 2:
            NSLog(@"2");
        case 3:
            NSLog(@"3");
            
        default:
            break;
    }
    
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
    r.HTTPMethod = @"POST";
//    [r.HTTPBodyStream open];
    return [_s dataTaskWithRequest:r];
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {

}



- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable))completionHandler {
    
}

//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
//    
//}



@end
