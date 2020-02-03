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

@interface YMViewController ()

@property (nonatomic, strong) YMMultiHandle *mh;

@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    dispatch_queue_t queue = dispatch_queue_create("com.aaa.bbb.ccc", DISPATCH_QUEUE_CONCURRENT);
    _mh = [[YMMultiHandle alloc] initWithConfiguration:nil WorkQueue:queue];
    YMEasyHandle *eh = [[YMEasyHandle alloc] initWithDelegate:nil];
    [_mh addHandle:eh];
    
    [NSURLSessionConfiguration defaultSessionConfiguration];
    [[YMURLSessionConfiguration defaultSessionConfiguration] HTTPAdditionalHeaders];
    [YMURLSession sessionWithConfiguration:nil];
    
    NSURLSessionTask
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end