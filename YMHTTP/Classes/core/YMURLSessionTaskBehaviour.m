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
        self.type = YMURLSessionTaskBehaviourTypeTaskDelegate;
    }
    return self;
}

- (instancetype)initWithDataTaskCompeltion:(YMDataTaskCompletion)dataTaskCompeltion {
    self = [super init];
    if (self) {
        self.type = YMURLSessionTaskBehaviourTypeDataHandler;
        self.dataTaskCompeltion = dataTaskCompeltion;
    }
    return self;
}

- (instancetype)initWithDownloadTaskCompeltion:(YMDownloadTaskCompletion)downloadTaskCompeltion {
    self = [super init];
    if (self) {
        self.type = YMURLSessionTaskBehaviourTypeDownloadHandler;
        self.downloadCompletion = downloadTaskCompeltion;
    }
    return self;
}

@end
