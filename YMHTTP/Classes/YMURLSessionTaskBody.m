//
//  YMURLSessionTaskBody.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMURLSessionTaskBody.h"

@implementation YMURLSessionTaskBody

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBodyTypeNone;
    }
    return self;
}

-(instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBodyTypeData;
        _data = data;
    }
    return self;
}

-(instancetype)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBodyTypeFile;
        _fileURL = fileURL;
    }
    return self;
}

-(instancetype)initWithInputStream:(NSInputStream *)InputStream {
    self = [super init];
    if (self) {
        _type = YMURLSessionTaskBodyTypeStream;
        _inputStream = InputStream;
    }
    return self;
}

- (NSNumber *)getBodyLengthWithError:(NSError **)error {
    switch (_type) {
        case YMURLSessionTaskBodyTypeNone:
            return @(0);
        case YMURLSessionTaskBodyTypeData:
            return [NSNumber numberWithUnsignedInteger:[_data length]];
        case YMURLSessionTaskBodyTypeFile:
        {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_fileURL.path error:error];
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
