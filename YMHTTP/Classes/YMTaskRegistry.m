//
//  YMTaskRegistry.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import "YMTaskRegistry.h"
#import "YMURLSessionTask.h"

@interface YMTaskRegistry ()

@property (nonatomic, strong) void (^tasksCompletion)(void);

@end

@implementation YMTaskRegistry

- (instancetype)init {
    self = [super init];
    if (self) {
        _tasks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSArray *)allTasks {
    return [_tasks allValues];
}

- (BOOL)isEmpty {
    return [_tasks count];
}

- (void)notifyOnTasksCompletion:(void (^)(void))tasksCompletion {
    _tasksCompletion = tasksCompletion;
}

- (void)addWithTask:(YMURLSessionTask *)task {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        // TODO: throw
    }
    NSString *key = @(task.taskIdentifier).stringValue;
    if (_tasks[key]) {
        if ([_tasks[key] isEqual:task]) {
        } else {
        }
    }
    _tasks[key] = task;
}

- (void)removeWithTask:(YMURLSessionTask *)task {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        // TODO: throw
    }
    NSString *key = @(task.taskIdentifier).stringValue;
    if (!_tasks[key]) {
        // TODO: throw
    }
    [_tasks removeObjectForKey:key];

    if (_tasksCompletion && [self isEmpty]) {
        _tasksCompletion();
    }
}

@end
