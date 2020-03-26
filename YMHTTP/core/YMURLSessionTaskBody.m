//
//  YMURLSessionTaskBody.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMURLSessionTaskBody.h"

@interface YMURLSessionTaskBody ()

@property (readwrite, nonatomic, assign) YMURLSessionTaskBodyType type;
@property (readwrite, nonatomic, strong) NSData *data;
@property (readwrite, nonatomic, strong) NSURL *fileURL;
@property (readwrite, nonatomic, strong) NSInputStream *inputStream;

@end

@implementation YMURLSessionTaskBody

- (instancetype)init {
    self = [super init];
    if (self) {
        self.type = YMURLSessionTaskBodyTypeNone;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        self.type = YMURLSessionTaskBodyTypeData;
        self.data = data;
    }
    return self;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self) {
        self.type = YMURLSessionTaskBodyTypeFile;
        self.fileURL = fileURL;
    }
    return self;
}

- (instancetype)initWithInputStream:(NSInputStream *)InputStream {
    self = [super init];
    if (self) {
        self.type = YMURLSessionTaskBodyTypeStream;
        self.inputStream = InputStream;
    }
    return self;
}

- (NSNumber *)getBodyLengthWithError:(NSError **)error {
    switch (self.type) {
        case YMURLSessionTaskBodyTypeNone:
            return @(0);
        case YMURLSessionTaskBodyTypeData:
            return [NSNumber numberWithUnsignedInteger:[self.data length]];
        case YMURLSessionTaskBodyTypeFile: {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.fileURL.path
                                                                                        error:error];
            if (!error) {
                NSNumber *size = attributes[NSFileSize];
                return size;
            }
            return nil;
        }
        case YMURLSessionTaskBodyTypeStream:
            return nil;
    }
}

@end
