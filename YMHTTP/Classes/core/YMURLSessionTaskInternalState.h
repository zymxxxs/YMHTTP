//
//  YMURLSessionTaskInternalState.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/7.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YMURLSessionTaskInternalStateType) {
    YMURLSessionTaskInternalStateTypeInitial,
    YMURLSessionTaskInternalStateTypeFulfillingFromCache,
    YMURLSessionTaskInternalStateTypeTransferInProgress,
    YMURLSessionTaskInternalStateTypeTransferCompleted,
    YMURLSessionTaskInternalStateTypeTransferFailed,
    YMURLSessionTaskInternalStateTypeWaitingForRedirectHandler,
    YMURLSessionTaskInternalStateTypeWaitingForResponseHandler,
    YMURLSessionTaskInternalStateTypeTaskCompleted,
};

NS_ASSUME_NONNULL_BEGIN

@interface YMURLSessionTaskInternalState : NSObject

@property (nonatomic, assign) YMURLSessionTaskInternalStateType type;

@end

NS_ASSUME_NONNULL_END
