//
//  YMURLSessionTaskBody.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, YMURLSessionTaskBodyType) {
    YMURLSessionTaskBodyTypeNone,
    YMURLSessionTaskBodyTypeData,
    YMURLSessionTaskBodyTypeFile,
    YMURLSessionTaskBodyTypeStream,
};

NS_ASSUME_NONNULL_BEGIN

@interface YMURLSessionTaskBody : NSObject

@property (readonly, nonatomic, assign) YMURLSessionTaskBodyType type;
@property (readonly, nonatomic, strong) NSData *data;
@property (readonly, nonatomic, strong) NSURL *fileURL;
@property (readonly, nonatomic, strong) NSInputStream *inputStream;


- (instancetype)init;
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (instancetype)initWithInputStream:(NSInputStream *)InputStream;


/// - Returns: The body length, or `nil` for no body (e.g. `GET` request).
-(NSNumber *)getBodyLengthWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
