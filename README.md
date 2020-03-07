# YMHTTP

[![CI Status](https://img.shields.io/travis/zymxxxs/YMHTTP.svg?style=flat)](https://travis-ci.org/zymxxxs/YMHTTP)
[![Version](https://img.shields.io/cocoapods/v/YMHTTP.svg?style=flat)](https://cocoapods.org/pods/YMHTTP)
[![License](https://img.shields.io/cocoapods/l/YMHTTP.svg?style=flat)](https://cocoapods.org/pods/YMHTTP)
[![Platform](https://img.shields.io/cocoapods/p/YMHTTP.svg?style=flat)](https://cocoapods.org/pods/YMHTTP)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

YMHTTP is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'YMHTTP'
```


## TODO:
* 使用 use_frameworks! 无法在真机运行
* 移除 YMURLSessionDataTask 以及 YMURLSessionUploadTask 的概念，只保留了 YMURLSessionTask（delegate 中的命名以及对象命名） [待考虑是否继续保留还是移除]
* conformsToProtocol 考虑是否移除
* ~~statusheader == [3] 解析错误~~
* ~~cache 待解决~~
* ~~download 不支持断点续传 待解决~~
* taskhandle
* ~~fatalError~~
* YMURLSessionTaskProtocolState 需要重新命名
* YMURLSessionTaskProtocolStateInvalidated 可能无用
* ~~多次 resume、suspend 之后 crash~~
    * resume, respend 需要配对
* ~~先异步获取 cache，后判断 cacheProxy，目前已经实现，相对逻辑简单，比较好控制（或者先判断 cacheProxy 然后根据实际情况获取 cache，以及后续操作，待操作）~~
* ~~目前需要在获取 response 以及 receive data 之后记录数据~~
* 待验证目前 cache 逻辑，cache 逻辑存在大量错误
* 相应缓存以及可以缓存应该调整为不同的逻辑
* ugly code 需要调整
* didReceiveResponse 在有缓存的情况下会crash
* 移除 delegatequeue 参数


# 待预研
* NSURLSession 中 suspend 无效