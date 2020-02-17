//
//  YMURLSessionTaskBehaviour.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMURLSessionTaskBehaviour.h"

@implementation YMURLSessionTaskBehaviour

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBehaviourTypeTaskDelegate;
    }
    return self;
}

- (instancetype)initWithDataTaskCompeltion:(YMDataTaskCompletion)dataTaskCompeltion {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBehaviourTypeDataHandler;
        _dataTaskCompeltion = dataTaskCompeltion;
    }
    return self;
}

- (instancetype)initWithDownloadTaskCompeltion:(YMDownloadTaskCompletion)downloadTaskCompeltion {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBehaviourTypeDownloadHandler;
        _downloadCompletion = downloadTaskCompeltion;
    }
    return self;
}

@end
