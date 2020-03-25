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
        self.tasks = [[NSMutableDictionary alloc] init];
        self.behaviours = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSArray *)allTasks {
    return [self.tasks allValues];
}

- (BOOL)isEmpty {
    return [self.tasks count] == 0;
}

- (void)notifyOnTasksCompletion:(void (^)(void))tasksCompletion {
    self.tasksCompletion = tasksCompletion;
}

- (void)addWithTask:(YMURLSessionTask *)task behaviour:(YMURLSessionTaskBehaviour *)behaviour {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        YM_FATALERROR(@"Invalid task identifier");
    }
    NSString *identifier = @(taskIdentifier).stringValue;
    if (self.tasks[identifier]) {
        if ([self.tasks[identifier] isEqual:task]) {
            YM_FATALERROR(@"Trying to re-insert a task that's already in the registry.");
        } else {
            YM_FATALERROR(
                @"Trying to insert a task, but a different task with the same identifier is already in the registry.");
        }
    }
    self.tasks[identifier] = task;
    self.behaviours[identifier] = behaviour;
}

- (void)removeWithTask:(YMURLSessionTask *)task {
    NSUInteger taskIdentifier = task.taskIdentifier;
    if (taskIdentifier == 0) {
        YM_FATALERROR(@"Invalid task identifier");
    }
    NSString *identifier = @(taskIdentifier).stringValue;
    if (!self.tasks[identifier]) {
        YM_FATALERROR(@"Trying to remove task, but it's not in the registry.");
    }
    [self.tasks removeObjectForKey:identifier];

    if (!self.behaviours[identifier]) {
        YM_FATALERROR(@"Trying to remove task's behaviour, but it's not in the registry.");
    }
    [self.behaviours removeObjectForKey:identifier];

    if (self.tasksCompletion && [self isEmpty]) {
        self.tasksCompletion();
    }
}

- (YMURLSessionTaskBehaviour *)behaviourForTask:(YMURLSessionTask *)task {
    NSString *identifier = @(task.taskIdentifier).stringValue;
    if (self.behaviours[identifier])
        return self.behaviours[identifier];
    else {
        YM_FATALERROR(@"Trying to access a behaviour for a task that in not in the registry.");
    }
    return nil;
}

@end
