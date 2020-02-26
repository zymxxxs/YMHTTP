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
    
    //        __block YMURLSessionTask *task = [self runWithURL:[NSURL URLWithString:@"https://httpbin.org/post"]];
    //        [task resume];
    
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //        [task suspend];
    //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //            [task resume];
    //        });
    //    });
    //    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://61.135.169.125"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"https://www.tmall.com"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://www.baidu.com"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    //    [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    
    //    int i = 0;
    //    while (i<50) {
    //        [[self runWithURL:[NSURL URLWithString:@"http://gank.io/api/today"]] resume];
    //        i++;
    //    }
    
    //    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://61.135.169.125"]];
    //    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    //
    //    }];
    //    [task resume];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        char *c1 = (char *)malloc(sizeof(char)*4096*1000);
//        char *c2 = (char *)malloc(sizeof(char)*4096*1000);
//        memset(c1, 1, sizeof(char)*4096*1000);
//        memset(c2, 1, sizeof(char)*4096*1000);
//        
//        dispatch_data_t d1 = dispatch_data_create(c1, sizeof(char)*4096*500, nil, DISPATCH_DATA_DESTRUCTOR_FREE);
//
//        dispatch_data_t d2 = dispatch_data_create(c2, sizeof(char)*4096*500, nil, DISPATCH_DATA_DESTRUCTOR_FREE);
//
//        dispatch_data_t d3 = dispatch_data_create_concat(d1, d2);
//
//        dispatch_data_t d4 = dispatch_data_create_subrange(d3, sizeof(char)*4096*250, sizeof(char)*4096*500);
//
//        dispatch_data_apply(d4, ^bool(dispatch_data_t  _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
//            NSLog(@"%@", region);
//            NSLog(@"%@", @(offset));
//            NSLog(@"%@", [NSString stringWithUTF8String:buffer]);
//            NSLog(@"%@", @(size));
//            return  YES;
//        });
//    });
    
    
    
    //    NSString *s = @"123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789";
    //    NSData *data = [NSData dataWithBytes:[s UTF8String] length:s.length];
    //
    //    while (data) {
    //        NSData *head = [data subdataWithRange:NSMakeRange(0, 1)];
    //        NSLog(@"%@", [[NSString alloc] initWithData:head encoding:NSUTF8StringEncoding]);
    //        if (data.length == 1) return;
    //        data = [data subdataWithRange:NSMakeRange(1, data.length-1)];
    //    }
    
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //        for (int i=0; i<1000; i++) {
    //            char a[4096*sizeof(char *)*100];
    //            strcpy(a, "aaadfadfdasfasdjfasdkjfa;dskjfas;d");
    //        }
    //    });
}



- (YMURLSessionTask *)runWithURL:(NSURL *)URL {
    
    NSMutableURLRequest *r = [[NSMutableURLRequest alloc] initWithURL:URL];
    NSURL *b = [[NSBundle mainBundle] URLForResource:@"aaa" withExtension:@"txt"];
    NSString *a = [NSString stringWithContentsOfURL:b
                                           encoding:NSUTF8StringEncoding
                                              error:nil];
    r.HTTPBody = [a dataUsingEncoding:NSUTF8StringEncoding];
    [r setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBodyStream = [[NSInputStream alloc] initWithData:[a dataUsingEncoding:NSUTF8StringEncoding]];
    r.HTTPMethod = @"POST";
    //        [r.HTTPBodyStream open];
    return [_s taskWithRequest:r fromFile:b];
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


//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
//    NSLog(@"didReceiveResponse");
////    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        completionHandler(YMURLSessionResponseAllow);
////    });
//}




@end
