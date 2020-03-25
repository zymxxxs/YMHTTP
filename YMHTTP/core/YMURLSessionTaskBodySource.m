//
//  YMURLSessionTaskBodySource.m
//  YMHTTP
//
//  Created by zymxxxs on 2020/2/8.
//

#import "YMURLSessionTaskBodySource.h"
#import "YMMacro.h"

@interface YMBodyStreamSource ()

@property (nonatomic, strong) NSInputStream *inputStream;

@end

@implementation YMBodyStreamSource

- (instancetype)initWithInputStream:(NSInputStream *)inputStream {
    self = [super init];
    if (self) {
        self.inputStream = inputStream;
        if (self.inputStream.streamStatus == NSStreamStatusNotOpen) {
            [self.inputStream open];
        }
    }
    return self;
}

- (void)getNextChunkWithLength:(NSInteger)length
             completionHandler:(void (^)(YMBodySourceDataChunk, NSData *_Nullable))completionHandler {
    if (!completionHandler) return;

    if (![self.inputStream hasBytesAvailable]) {
        completionHandler(YMBodySourceDataChunkDone, nil);
        return;
    }

    uint8_t buffer[length];
    NSInteger readBytes = [self.inputStream read:buffer maxLength:length];
    if (readBytes > 0) {
        NSData *data = [[NSData alloc] initWithBytes:buffer length:readBytes];
        completionHandler(YMBodySourceDataChunkData, data);
    } else if (readBytes == 0) {
        completionHandler(YMBodySourceDataChunkDone, nil);
    } else {
        completionHandler(YMBodySourceDataChunkError, nil);
    }
}

@end

@interface YMBodyDataSource ()

@property (nonatomic, strong) NSData *data;

@end

@implementation YMBodyDataSource

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        self.data = data;
    }
    return self;
}

- (void)getNextChunkWithLength:(NSInteger)length
             completionHandler:(nonnull void (^)(YMBodySourceDataChunk, NSData *_Nullable))completionHandler {
    if (!completionHandler) return;
    NSUInteger remaining = self.data.length;
    if (remaining == 0) {
        completionHandler(YMBodySourceDataChunkDone, nil);
    } else if (remaining <= length) {
        NSData *r = [[NSData alloc] initWithData:self.data];
        self.data = nil;
        completionHandler(YMBodySourceDataChunkData, r);
    } else {
        NSData *chunk = [self.data subdataWithRange:NSMakeRange(0, length)];
        NSData *remainder = [self.data subdataWithRange:NSMakeRange(length - 1, self.data.length - length)];
        self.data = remainder;
        completionHandler(YMBodySourceDataChunkData, chunk);
    }
}

@end

typedef NS_ENUM(NSUInteger, YMBodyFileSourceChunk) {
    YMBodyFileSourceChunkEmpty,
    YMBodyFileSourceChunkErrorDetected,
    YMBodyFileSourceChunkData,
    YMBodyFileSourceChunkDone,
};

@interface YMBodyFileSource ()

@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) dispatch_io_t channel;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, strong) void (^dataAvailableHandler)(void);
@property (assign) BOOL hasActiveReadHandler;
@property (nonatomic, assign) YMBodyFileSourceChunk availableChunk;
@property (nonatomic, strong) dispatch_data_t availableData;

@property (readonly, assign) NSInteger availableByteCount;
@property (readonly, assign) NSInteger desiredBufferLength;

@end

@implementation YMBodyFileSource

- (instancetype)initWithFileURL:(NSURL *)fileURL
                      workQueue:(dispatch_queue_t)workQueue
           dataAvailableHandler:(void (^)(void))dataAvailableHandler {
    self = [super init];
    if (self) {
        if (![fileURL isFileURL]) YM_FATALERROR(@"The body data URL must be a file URL.");

        self.fileURL = fileURL;
        self.workQueue = workQueue;
        self.dataAvailableHandler = dataAvailableHandler;

        const char *fileSystemRepresentation = fileURL.fileSystemRepresentation;
        if (fileSystemRepresentation != NULL) {
            int fd = open(fileSystemRepresentation, O_RDONLY);
            self.channel = dispatch_io_create(DISPATCH_IO_STREAM,
                                              fd,
                                              workQueue,
                                              ^(int error){
                                              });
        } else {
            YM_FATALERROR(@"Can't create DispatchIO channel");
        }
        dispatch_io_set_high_water(_channel, CURL_MAX_WRITE_SIZE);
    }
    return self;
}

- (void)readNextChunk {
    // libcurl likes to use a buffer of size CURL_MAX_WRITE_SIZE, we'll
    // try to keep 3 x of that around in the `chunk` buffer.
    if (self.availableByteCount >= self.desiredBufferLength) return;

    if (self.hasActiveReadHandler) return;
    self.hasActiveReadHandler = true;

    NSInteger lengthToRead = self.desiredBufferLength - self.availableByteCount;
    dispatch_io_read(
        self.channel, 0, lengthToRead, self.workQueue, ^(bool done, dispatch_data_t _Nullable data, int error) {
            BOOL wasEmpty = self.availableByteCount == 0;

            self.hasActiveReadHandler = !done;

            if (done == true && error != 0) {
                self.availableChunk = YMBodyFileSourceChunkErrorDetected;
            } else if (done == true && error == 0) {
                if (dispatch_data_get_size(data) == 0) {
                    [self appendData:data endOfFile:true];
                } else {
                    [self appendData:data endOfFile:false];
                }
            } else if (done == false && error == 0) {
                [self appendData:data endOfFile:false];
            } else {
                YM_FATALERROR(@"Invalid arguments to read(3) callback.");
            }

            if (wasEmpty && self.availableByteCount >= 0) {
                self.dataAvailableHandler();
            }
        });
}

- (void)appendData:(dispatch_data_t)data endOfFile:(BOOL)endOfFile {
    if (self.availableChunk == YMBodyFileSourceChunkEmpty) {
        self.availableData = data;
        if (endOfFile) {
            self.availableChunk = YMBodyFileSourceChunkDone;
        } else {
            self.availableChunk = YMBodyFileSourceChunkData;
        }
        return;
    }

    if (self.availableChunk == YMBodyFileSourceChunkData) {
        dispatch_data_t newData = dispatch_data_create_concat(self.availableData, data);
        self.availableData = newData;
        if (endOfFile) {
            _availableChunk = YMBodyFileSourceChunkDone;
        } else {
            self.availableChunk = YMBodyFileSourceChunkData;
        }
        return;
    }

    if (self.availableChunk == YMBodyFileSourceChunkDone) {
        YM_FATALERROR(@"Trying to append data, but end-of-file was already detected.");
    }
}

- (NSInteger)availableByteCount {
    switch (self.availableChunk) {
        case YMBodyFileSourceChunkEmpty:
            return 0;
        case YMBodyFileSourceChunkErrorDetected:
            return 0;
        case YMBodyFileSourceChunkData:
            return dispatch_data_get_size(_availableData);
            ;
        case YMBodyFileSourceChunkDone: {
            if (self.availableData == nil) {
                return 0;
            } else {
                return dispatch_data_get_size(_availableData);
            }
        }
    }
}

- (NSInteger)desiredBufferLength {
    return 3 * CURL_MAX_WRITE_SIZE;
}

- (void)getNextChunkWithLength:(NSInteger)length
             completionHandler:(void (^)(YMBodySourceDataChunk, NSData *_Nullable))completionHandler {
    switch (self.availableChunk) {
        case YMBodyFileSourceChunkEmpty: {
            [self readNextChunk];
            completionHandler(YMBodySourceDataChunkRetryLater, nil);
            break;
        }
        case YMBodyFileSourceChunkErrorDetected:
            completionHandler(YMBodySourceDataChunkError, nil);
            break;
        case YMBodyFileSourceChunkData: {
            NSInteger l = dispatch_data_get_size(_availableData);
            NSInteger p = MIN(length, dispatch_data_get_size(_availableData));

            dispatch_data_t head = dispatch_data_create_subrange(_availableData, 0, p);
            dispatch_data_t tail = dispatch_data_create_subrange(_availableData, p - 1, l - p);

            if (dispatch_data_get_size(tail) == 0) {
                self.availableChunk = YMBodyFileSourceChunkEmpty;
            } else {
                self.availableChunk = YMBodyFileSourceChunkData;
                self.availableData = tail;
            }
            [self readNextChunk];

            size_t headCount = dispatch_data_get_size(head);
            if (headCount == 0) {
                completionHandler(YMBodySourceDataChunkRetryLater, nil);
            } else {
                char *buffer = (char *)malloc(sizeof(char) * headCount);
                [self copyBytesFromData:head toBuffer:buffer count:headCount];
                completionHandler(YMBodySourceDataChunkData, [NSData dataWithBytesNoCopy:buffer length:p]);
            }
            break;
        }
        case YMBodyFileSourceChunkDone: {
            if (self.availableData == nil) {
                completionHandler(YMBodySourceDataChunkDone, nil);
                break;
            }

            NSInteger l = dispatch_data_get_size(self.availableData);
            NSInteger p = MIN(length, dispatch_data_get_size(self.availableData));

            dispatch_data_t head = dispatch_data_create_subrange(self.availableData, 0, p);
            dispatch_data_t tail = dispatch_data_create_subrange(self.availableData, p - 1, l - p);

            if (dispatch_data_get_size(tail) == 0) {
                self.availableChunk = YMBodyFileSourceChunkDone;
                self.availableData = nil;
            } else {
                self.availableChunk = YMBodyFileSourceChunkDone;
                self.availableData = tail;
            }

            size_t headCount = dispatch_data_get_size(head);
            if (headCount == 0) {
                completionHandler(YMBodySourceDataChunkDone, nil);
            } else {
                char *buffer = (char *)malloc(sizeof(char) * headCount);
                [self copyBytesFromData:head toBuffer:buffer count:headCount];
                completionHandler(YMBodySourceDataChunkData, [NSData dataWithBytesNoCopy:buffer length:p]);
            }
            break;
        }
    }
}

- (void)copyBytesFromData:(dispatch_data_t)data toBuffer:(char *)buffer count:(NSInteger)count {
    if (count == 0) return;

    __block NSInteger copiedCount = 0;
    NSInteger startIndex = 0;
    NSInteger endIndex = count - 1;

    dispatch_data_apply(data,
                        ^bool(dispatch_data_t _Nonnull region, size_t offset, const void *_Nonnull ptr, size_t size) {
                            if (offset >= endIndex) return false;  // This region is after endIndex
                            NSInteger copyOffset =
                                startIndex > offset ? startIndex - offset : 0;  // offset of first byte, in this region
                            if (copyOffset >= size) return true;                // This region is before startIndex
                            NSInteger n = MIN(count - copiedCount, size - copyOffset);
                            memcpy(buffer + copiedCount, ptr + copyOffset, n);
                            copiedCount += n;
                            return copiedCount < count;
                        });
}

@end
