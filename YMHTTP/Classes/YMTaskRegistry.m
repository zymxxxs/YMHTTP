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
        _behaviours = [[NSMutableDictionary alloc] init];
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

- (void)addWithTask:(YMURLSessionTask *)task behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        // TODO: throw
    }
    NSString *identifier = @(taskIdentifier).stringValue;
    if (_tasks[identifier]) {
        if ([_tasks[identifier] isEqual:task]) {
        } else {
        }
    }
    _tasks[identifier] = task;
    _behaviours[identifier] = behaviour;
}

- (void)removeWithTask:(YMURLSessionTask *)task behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        // TODO: throw
    }
    NSString *identifier = @(taskIdentifier).stringValue;
    if (!_tasks[identifier]) {
        // TODO: throw
    }
    [_tasks removeObjectForKey:identifier];

    if (!_behaviours[identifier]) {
        // TODO: throw
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
        // TODO: Throw Error
        return nil;
    }
}

@end
