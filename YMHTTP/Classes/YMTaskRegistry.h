//
//  YMTaskRegistry.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import <Foundation/Foundation.h>

@class YMURLSessionTask;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, YMTaskRegistryBehaviour) {
    YMTaskRegistryBehaviourDelegate,
    MyEnumValueBYMTaskRegistryBehaviourCompletionHandler,
};

@interface YMTaskRegistry : NSObject

@property (nonatomic, strong) NSMutableDictionary<NSString *, YMURLSessionTask *> *tasks;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *behaviours;
@property (readonly, nonatomic, strong) NSArray *allTasks;
@property (readonly, nonatomic, assign) BOOL isEmpty;
@property (nonatomic, assign) YMTaskRegistryBehaviour behaviour;

- (void)addWithTask:(YMURLSessionTask *)task;

- (void)removeWithTask:(YMURLSessionTask *)task;

- (void)notifyOnTasksCompletion:(void (^)(void))tasksCompletion;

@end

NS_ASSUME_NONNULL_END
