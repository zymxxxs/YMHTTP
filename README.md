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
* statusheader == [3] 解析错误
* cache 待解决
* download 不支持断点续传 待解决
