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

@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    YMURLSession *s = [YMURLSession sessionWithConfiguration:[YMURLSessionConfiguration defaultSessionConfiguration]
                                                    delegate:self
                                               delegateQueue:nil];
    YMURLSessionTask *d = [s dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]]];
    [d resume];
    
    NSURLRequest *r = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
    }];
    [task resume];
    

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
    
//    curl_post_req();
    
}

//- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable))completionHandler {
//    
//}

CURLM *mcurl;

CURLcode curl_post_req()
{
    // init curl
    mcurl = curl_multi_init();
//    if (mcurl) {
        // timeout
        curl_multi_setopt(mcurl, CURLMOPT_TIMERDATA, NULL);
        curl_multi_setopt(mcurl, CURLMOPT_TIMERFUNCTION, __curlm_timer_function);
//    }
    // res code
//    CURLcode res;
//    {
        // set params
    CURL *curl = curl_easy_init();
        curl_easy_setopt(curl, CURLOPT_URL, "http://www.baidu.com"); // url
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, false); // if want to use https
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, false); // set peer and host verify false
        curl_easy_setopt(curl, CURLOPT_VERBOSE, 1);
        curl_easy_setopt(curl, CURLOPT_READFUNCTION, NULL);
        curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
        curl_easy_setopt(curl, CURLOPT_HEADER, 1);
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 3);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 3);
        // start req
//        res = curl_easy_perform(curl);
        
//    }
    
    curl_multi_add_handle(mcurl, curl);
    
    // release curl
    //    curl_easy_cleanup(curl);
    return 0;
}

int __curlm_timer_function(YMURLSessionEasyHandle easyHandle, int timeout, void *userdata) {
    NSLog(@"hahahahhahahah %@", @(timeout));
    int runningHandlesCount = 0;
    curl_multi_socket_action(mcurl, CURL_SOCKET_TIMEOUT, 0, &runningHandlesCount);
    return 0;
}

@end
