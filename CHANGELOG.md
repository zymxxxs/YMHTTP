## 1.0.0-beta.3
---
* fix: task 不再触发 needNewBodyStream 回调
* fix: 重定向请求继续使用之前的超时时间
* fix: HTTPBody length == 0 与 HTTPBody == nil 保持同等处理
* fix: 对于 POST 请求设置默认 Content-Type 字段
* feat: 处理 3xx 请求，willPerformHTTPRedirection 回调更加合理

## 1.0.0-beta.2
---
* fix: GET 请求不再设置 `Content-Length`
* feat: 支持 CURLOPT_XFERINFOFUNCTION，NSProgress 获取进度更加准确
* fix: redirect 逻辑完善

## 1.0.0-beta.1
---
* first dev version
