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
#import <Security/Security.h>
#import <objc/runtime.h>
#import "NSURLRequest+YMCategory.h"

typedef NS_OPTIONS(NSUInteger, YMState) {
    YMStateReceive = 1 << 0,
    YMStateSend = 1 << 1
};

@interface YMViewController ()<YMURLSessionDataDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) YMURLSession *s;
@property (strong) NSURLRequest *request;

@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    YMURLSessionConfiguration *c = [YMURLSessionConfiguration defaultSessionConfiguration];
    self.s = [YMURLSession sessionWithConfiguration:c
                                           delegate:self
                                      delegateQueue:nil];
    
    YMURLSessionTask *task = [self.s taskWithURL:[NSURL URLWithString:@"http://httpbin.org/cache/20"]
                                   connectToHost:@"34.230.193.231"
                               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSLog(@"%@", response);
        NSLog(@"%@", error);
    }];
    [task resume];
    //    [task suspend];
    //    [task cancel];
    
    //    for (int i=0;i<10; i++) {
    //        YMURLSessionTask *task = [self.s taskWithURL:[NSURL URLWithString:@"http://httpbin.org/get"]];
    //        [task resume];
    //    }
    
    
    //    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://httpbin.org/cache/200"]];
    //    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    //    config.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    //    config.timeoutIntervalForRequest = 5.f;
    //    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
    //                                                          delegate:self
    //                                                     delegateQueue:nil];
    //    NSURLSessionTask *t = [session dataTaskWithRequest:r];
    //    [t resume];
    //
    //    NSURLSessionTask *t1 = [session dataTaskWithRequest:r];
    //    [t1 resume];
    //
    //    NSURLSessionTask *t2 = [session dataTaskWithRequest:r];
    //    [t2 resume];
    
    
    
    //
    //
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //        <#code to be executed after a specified delay#>
    //    });
    
    //    [[NSURLCache sharedURLCache] getCachedResponseForDataTask:t completionHandler:^(NSCachedURLResponse * _Nullable cachedResponse) {
    //
    //    }];
}

//-(void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
//    completionHandler(YMURLSessionResponseAllow);
//}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"didCompleteWithError");
    //    NSLog(@"%@", task.response.allHeaderFields);
    //    NSLog(@"%@", error);
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData");
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    //    completionHandler(proposedResponse);
}


-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    NSLog(@"%@ %@ %@", @(bytesSent), @(totalBytesSent), @(totalBytesExpectedToSend));
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData");
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    completionHandler(NSURLSessionResponseAllow);
    //        });
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"didCompleteWithError");
    //    NSLog(@"%@", task.response);
    //    NSLog(@"%@", error);
}



- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler {
    //    completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    completionHandler(request);
}





@end
