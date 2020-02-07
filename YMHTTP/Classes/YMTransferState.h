//
//  YMTransferState.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YMDataDrain) {
    YMDataDrainInMemory,
    YMDataDrainToFile,
    YMDataDrainIgnore,
};

NS_ASSUME_NONNULL_BEGIN

@interface YMTransferState : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, assign) YMDataDrain dataDrain;

@end


typedef NS_ENUM(NSUInteger, YMParsedResponseHeaderType) {
    YMParsedResponseHeaderTypePartial,
    YMParsedResponseHeaderTypeComplete
};

@interface YMParsedResponseHeader : NSObject

@property (nonatomic, assign) YMParsedResponseHeaderType type;
@property (nonatomic, strong) NSMutableArray<NSString *> *headerLines;

- (instancetype)ByAppendingHeaderLine:(NSData *)data onHeaderCompleted:(BOOL(^)(NSString *headerLine))onHeaderCompleted;



@end




NS_ASSUME_NONNULL_END
