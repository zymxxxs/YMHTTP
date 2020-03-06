//
//  YMTaskRegistry.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/5.
//

#import "YMTaskRegistry.h"
#import "YMMacro.h"
#import "YMURLSessionTask.h"

@interface YMTaskRegistry ()

@property (nonatomic, strong) void (^tasksCompletion)(void);

@end

@implementation YMTaskRegistry

- (instancetype)init {
    self = [super init];
    if (self) {
        _tasks = [[NSMutableDictionary alloc] init];
        _behaviours = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSArray *)allTasks {
    return [_tasks allValues];
}

- (BOOL)isEmpty {
    return [_tasks count] == 0;
}

- (void)notifyOnTasksCompletion:(void (^)(void))tasksCompletion {
    _tasksCompletion = tasksCompletion;
}

- (void)addWithTask:(YMURLSessionTask *)task behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        YM_FATALERROR(@"Invalid task identifier");
    }
    NSString *identifier = @(taskIdentifier).stringValue;
    if (_tasks[identifier]) {
        if ([_tasks[identifier] isEqual:task]) {
            YM_FATALERROR(@"Trying to re-insert a task that's already in the registry.");
        } else {
            YM_FATALERROR(
                @"Trying to insert a task, but a different task with the same identifier is already in the registry.");
        }
    }
    _tasks[identifier] = task;
    _behaviours[identifier] = behaviour;
}

- (void)removeWithTask:(YMURLSessionTask *)task {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        YM_FATALERROR(@"Invalid task identifier");
    }
    NSString *identifier = @(taskIdentifier).stringValue;
    if (!_tasks[identifier]) {
        YM_FATALERROR(@"Trying to remove task, but it's not in the registry.");
    }
    [_tasks removeObjectForKey:identifier];

    if (!_behaviours[identifier]) {
        YM_FATALERROR(@"Trying to remove task's behaviour, but it's not in the registry.");
    }
    [_behaviours removeObjectForKey:identifier];

    if (_tasksCompletion && [self isEmpty]) {
        _tasksCompletion();
    }
}

- (YMURLSessionTaskBehaviour *)behaviourForTask:(YMURLSessionTask *)task {
    NSString *identifier = @(task.taskIdentifier).stringValue;
    if (_behaviours[identifier])
        return _behaviours[identifier];
    else {
        YM_FATALERROR(@"Trying to access a behaviour for a task that in not in the registry.");
    }
    return nil;
}

@end
