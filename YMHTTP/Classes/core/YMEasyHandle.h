//
//  YMEasyHandle.h
//  YMHTTP
//
//  Created by zymxxxs on 2019/12/31.
//

#import <Foundation/Foundation.h>
#include "curl.h"

NS_ASSUME_NONNULL_BEGIN

@protocol YMEasyHandleDelegate

/// Handle data read from the network
- (void)didReceiveWithData:(NSData *)data;

/// Handle header data read from the network
- (void)didReceiveWithHeaderData:(NSData *)data contentLength:(int64_t)contentLength;

@end


typedef void * YMURLSessionEasyHandle;

@interface YMEasyHandle : NSObject

@property (nonatomic, assign) YMURLSessionEasyHandle rawHandle;
@property (nonatomic, weak, nullable) id<YMEasyHandleDelegate> delegate;
@property (nonatomic, strong, nullable) NSURL *url;

- (instancetype)initWithDelegate:(id<YMEasyHandleDelegate>)delegate;

- (int)urlErrorCodeWithEasyCode:(int)easyCode;


@end

NS_ASSUME_NONNULL_END
