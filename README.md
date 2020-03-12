# YMHTTP

`YMHTTP` 是一个适用于 iOS 的高性能异步网络框架。它建立在 [libcurl](https://curl.haxx.se/libcurl/) 的基础上，其 API 设计和行为与 NSURLSession 保持高度一致。

因为 `YMHTTP` 是基于 libcurl 进行封装，所以有着较高的定制性，目前的版本与 `NSURLSession` 在 API 设计与行为保持着高度一致，便于使用，极少二次理解，同时拓展了 DNS 的能力（包括 SNI）。

## 说明

1. 您可以通过 [NSURLSession](https://developer.apple.com/documentation/foundation/nsurlsession) 来查阅具体的细节。
2. YMHTTP 和 NSURLSession 非常像，一个是 YM 前缀，一个是 NS 前缀，对外提供的API相互一致
3. 如果您已经非常了解 NSURLSession，那么可以直接查阅 Connect to specific host and port 部分
4. 不支持 System Background Task 相关功能，这个真的无能为力

## 安装

目前 `YMHTTP` 的 `UT覆盖率` 在 80% 左右，覆盖代码各个 case，但仍有一些地方需要打磨，目前暂时没有发布正式版本。

```ruby
pod 'YMHTTP', :git => 'https://github.com/zymxxxs/YMHTTP.git'
```

## Requirements

* iOS 10.0 
* Xcode 11.3.1
* libcurl 7.64.1 + SecureTransport

## 使用

### 0x01 YMSession

```objc
// 创建 sharedSession
YMURLSession *sharedSession = [YMURLSession sharedSession];

// 使用指定配置创建会话
YMURLSessionConfiguration *config = [YMURLSessionConfiguration defaultSessionConfiguration];
YMURLSession *sessionNoDelegate = [YMURLSession sessionWithConfiguration:config];

// 创建具有指定会话配置，委托和操作队列的会话
YMURLSession *session = [YMURLSession sessionWithConfiguration:config
                                                                    delegate:self
                                                            delegateQueue:nil];
```

### 0x02 Adding Data Task to a Session

```objc
- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request;
- (YMURLSessionTask *)taskWithURL:(NSURL *)url;
```

通过指定 URL 或 Request 来创建一个任务

```objc
- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                    completionHandler:(void (^)(NSData *_Nullable data,
                                                NSHTTPURLResponse *_Nullable response,
                                                NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url
                completionHandler:(void (^)(NSData *_Nullable data,
                                            NSHTTPURLResponse *_Nullable response,
                                            NSError *_Nullable error))completionHandler;
```

通过指定 URL 或 Request 来创建任务，在任务完成后调用 completionHandler

#### Example

1. delegate 方式
```objc

// create
YMURLSessionTask *task = [session taskWithURL:[NSURL URLWithString:@"http://httpbin.org/get"]];
[task resume];

// delegate
- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didCompleteWithError:(NSError *)error {

}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveData:(NSData *)data {

}

- (void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    completionHandler(proposedResponse);
}

-(void)YMURLSession:(YMURLSession *)session task:(YMURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(YMURLSessionResponseDisposition))completionHandler {
    completionHandler(YMURLSessionResponseAllow);
}
```

2. completionHandler 方式

```objc
YMURLSessionTask *task = [session taskWithURL:[NSURL URLWithString:@"http://httpbin.org/get"] completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
    
}];
[task resume];
```

### 0x03 Adding Upload Tasks to a Session

```objc
- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;

- (YMURLSessionTask *)taskWithStreamedRequest:(NSURLRequest *)request;

```

通过指定 Request 来创建一个上传任务。

`taskWithStreamedRequest` 方法，会调用 `YMURLSession:task:needNewBodyStream:` delegate 方法，您需要通过 `completionHandler` 返回一个 `NSInputStream` 对象。当然你也可以功过 `NSURLMutableRequest` 创建对象，并在 `bodyStream` 传入 `NSInputStream` 对象。

如果您需要上传大文件，建议您使用 `fromFile` 方法，虽然 `taskWithStreamedRequest` 也支持大文件的传输，但其形式为循环执行 `读取指定长度内容 -> 上传该内容`，该行为在内部的线程是同步的，而 `fromFile` 方式则会每次异步获取 3 * CURL_MAX_WRITE_SIZE 长度的内容供 libcurl 进行上传（CURL_MAX_WRITE_SIZE 为单次支持最大上传的长度），不仅减少文件 IO 的次数，也减少同步阻塞的时间，优化上传效率。

```objc
- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                             fromFile:(NSURL *)fileURL
                    completionHandler:(void (^)(NSData *_Nullable data,
                                                NSHTTPURLResponse *_Nullable response,
                                                NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithRequest:(NSURLRequest *)request
                             fromData:(nullable NSData *)bodyData
                    completionHandler:(void (^)(NSData *_Nullable data,
                                                NSHTTPURLResponse *_Nullable response,
                                                NSError *_Nullable error))completionHandler;
```

通过指定 Request 来创建任务，在任务完成后调用 completionHandler


### 0x04 Adding Download Tasks to a Session

```objc
- (YMURLSessionTask *)taskWithDownloadRequest:(NSURLRequest *)request;

- (YMURLSessionTask *)taskWithDownloadURL:(NSURL *)url;
```

通过指定 Request 来创建一个下载任务，并返回临时文件，由于该文件是临时文件，因此必须打开该文件进行读取，或将其移动到应用程序沙盒容器目录中的永久位置，支持大文件下载。

当然你也可以使用 `taskWithRequest` 和 `taskWithURL` 来自定义下载任务。

```objc
- (YMURLSessionTask *)taskWithDownloadRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURL *_Nullable location,
                                                        NSHTTPURLResponse *_Nullable response,
                                                        NSError *_Nullable error))completionHandler;

- (YMURLSessionTask *)taskWithDownloadURL:(NSURL *)url
                        completionHandler:(void (^)(NSURL *_Nullable location,
                                                    NSHTTPURLResponse *_Nullable response,
                                                    NSError *_Nullable error))completionHandler;
```

### 0x05 Connect to specific host and port

```objc
- (YMURLSessionTask *)taskWithURL:(NSURL *)url connectToHost:(NSString *)host;

- (YMURLSessionTask *)taskWithURL:(NSURL *)url connectToHost:(NSString *)host connectToPort:(NSInteger)port;

// 创建包含 host port 的 request
[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://httpbin.org/get"] connectToHost:@"52.202.2.199"];
[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://httpbin.org/get"] connectToHost:@"52.202.2.199" connectToPort:443];
[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://httpbin.org/get"]
                           connectToHost:@"52.202.2.199"
                           connectToPort:443
                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                         timeoutInterval:60];
```

连接到特定的主机和端口，其中 host 支持 IP 的形式。如果使用正常的域名+host+port的请求方式，那么对于框架内部可以自动处理 Cookie，Cache 以及 302 等问题，当然该接口也支持 SNI 的场景。

备注：该接口不会影响到 DNS Cache，了解更多可以看这里 https://curl.haxx.se/libcurl/c/CURLOPT_CONNECT_TO.html。

## libcurl
当前使用 libcurl 7.64.1 的版本，与 macOS Catalina 中保持一致，使用[curl-android-ios](https://github.com/gcesarmza/curl-android-ios)进行构建，你也可以选择喜欢的版本进行构建

### HTTP/2
目前版本不支持 HTTP/2，你可以使用 [Build-OpenSSL-cURL](https://github.com/jasonacox/Build-OpenSSL-cURL.git) 进行构建支持 HTTP/2 功能的版本。

注意 `Build-OpenSSL-cURL` 中使用的是 openSSL，而目前 macOS Catalina 中则是使用 LibreSSL，目前没有找到相关的构建脚本，待后期以 `Build-OpenSSL-cURL` 的基础提供一个。

## 感谢
* [lindean](https://github.com/lindean) 破老师，目前就职于PDD。感谢其初版 HTTP DNS 的实现，作为先驱者，填了无数坑，尤其是 libcurl 中各种参数以及 Cache 层的相关实现
* [amendgit](https://github.com/amendgit) 二老师，人称二哥，目前就职于支付宝。感谢其在 `IO 多路复用` 上解惑与指导
* [libcurl](https://curl.haxx.se/libcurl/)
* [swift-corelibs-foundation](https://github.com/apple/swift-corelibs-foundation.git)
* [curl-android-ios](https://github.com/gcesarmza/curl-android-ios)
* [Build-OpenSSL-cURL](https://github.com/jasonacox/Build-OpenSSL-cURL.git)


## TODO:
* 使用 use_frameworks! 无法在真机运行
* 目前指定 IP 的能力通过 CURLOPT_CONNECT_TO 来解决，其好处是不会影响 DNS Cache，但是在 Charles 中无法抓包。待考虑是否替换为 CURLOPT_RESOLVE 参数，可以解决 Charles 抓包的问题，不过对于 DNS Cache 的问题，是否需要影响还是不能影响都要删除？或者是说DNS的能力，使用 CURLOPT_CONNECT_TO 还是 CURLOPT_RESOLVE 哪一个更为合理？
* 不支持断点续传，目前苹果 NSURLSession 对于断点续传功能的限制太多，感觉弱弱的，实现起来又麻烦，索性不实现了
* 目前大部分还是基于 AFNetworking 进行分封装，待考虑是否提供一个 YMNetworking 版本便于接入？