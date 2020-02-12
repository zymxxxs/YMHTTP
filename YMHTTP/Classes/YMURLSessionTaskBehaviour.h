//
//  YMURLSessionTaskBehaviour.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YMURLSessionTaskBehaviourType) {
    /// The session has no delegate, or just a plain `URLSessionDelegate`.
    YMURLSessionTaskBehaviourTypeNoDelegate,
    /// The session has a delegate of type `URLSessionTaskDelegate`
    YMURLSessionTaskBehaviourTypeTaskDelegate,
    /// Default action for all events, except for completion.
    YMURLSessionTaskBehaviourTypeDataHandler,
    /// Default action for all events, except for completion.
    YMURLSessionTaskBehaviourTypeDownloadHandler
};

NS_ASSUME_NONNULL_BEGIN

typedef void (^YMDataTaskCompletion)(NSData *_Nullable data,
                                     NSURLResponse *_Nullable response,
                                     NSError *_Nullable error);
typedef void (^YMDownloadTaskCompletion)(NSURL *_Nullable location,
                                         NSURLResponse *_Nullable response,
                                         NSError *_Nullable error);

@interface YMURLSessionTaskBehaviour : NSObject

@property (nonatomic, assign) YMURLSessionTaskBehaviourType type;
@property (nonatomic, strong) YMDataTaskCompletion dataTaskCompeltion;
@property (nonatomic, strong) YMDownloadTaskCompletion downloadCompletion;

- (instancetype)init;
- (instancetype)initWithDataTaskCompeltion:(YMDataTaskCompletion)dataTaskCompeltion;
- (instancetype)initWithDownloadTaskCompeltion:(YMDownloadTaskCompletion)downloadTaskCompeltion;

@end

NS_ASSUME_NONNULL_END
