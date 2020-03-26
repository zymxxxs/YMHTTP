//
//  NSArray+YMCategory.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/28.
//

#import "NSArray+YMCategory.h"

@implementation NSArray (YMCategory)

- (NSArray *)ym_map:(id (^)(id object))block {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];

    for (id object in self) {
        [array addObject:block(object) ?: [NSNull null]];
    }

    return array;
}

- (NSArray *)ym_filter:(BOOL (^)(id object))block {
    return [self
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return block(evaluatedObject);
        }]];
}

@end
