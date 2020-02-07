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
#import <CFNetwork/CFNetwork.h>

@interface YMViewController ()<NSURLSessionDataDelegate>

@property (nonatomic, strong) YMMultiHandle *mh;

@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

//    dispatch_queue_t queue = dispatch_queue_create("com.aaa.bbb.ccc", DISPATCH_QUEUE_CONCURRENT);
//    _mh = [[YMMultiHandle alloc] initWithConfiguration:nil WorkQueue:queue];
//    YMEasyHandle *eh = [[YMEasyHandle alloc] initWithDelegate:nil];
//    [_mh addHandle:eh];
//
//    [NSURLSessionConfiguration defaultSessionConfiguration];
//    [[YMURLSessionConfiguration defaultSessionConfiguration] HTTPAdditionalHeaders];
//    [YMURLSession sessionWithConfiguration:nil];
    
    NSURLSession *s = [NSURLSession sessionWithConfiguration:[NSURLSession sharedSession].configuration
                                                    delegate:self
                                               delegateQueue:nil];
    NSLog(@"%@", [[NSURLSession sharedSession] configuration].protocolClasses);
//    [[s dataTaskWithURL:[NSURL URLWithString:@"https://www.baidu.com"]] resume];
    
    [[s dataTaskWithURL:[NSURL URLWithString:@"https://www.baidu.com"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

    }] resume];

    

}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData");
    NSLog(@"%@", data);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"didCompleteWithError");
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    
    completionHandler(proposedResponse);
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
