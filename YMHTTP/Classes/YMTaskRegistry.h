//
//  YMTaskRegistry.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import <Foundation/Foundation.h>

@class YMURLSessionTask;
@class YMURLSessionTaskBehaviour;

NS_ASSUME_NONNULL_BEGIN

@interface YMTaskRegistry : NSObject

@property (nonatomic, strong) NSMutableDictionary<NSString *, YMURLSessionTask *> *tasks;
@property (nonatomic, strong) NSMutableDictionary<NSString *, YMURLSessionTaskBehaviour *> *behaviours;
@property (readonly, nonatomic, strong) NSArray *allTasks;
@property (readonly, nonatomic, assign) BOOL isEmpty;

- (void)addWithTask:(YMURLSessionTask *)task behaviour:(YMURLSessionTaskBehaviour *)behaviour;

- (void)removeWithTask:(YMURLSessionTask *)task behaviour:(YMURLSessionTaskBehaviour *)behaviour;

- (void)notifyOnTasksCompletion:(void (^)(void))tasksCompletion;

- (YMURLSessionTaskBehaviour *)behaviourForTask:(YMURLSessionTask *)task;

@end

NS_ASSUME_NONNULL_END
