//
//  YMMacro.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/1/3.
//

#import <Foundation/Foundation.h>
#import "curl.h"

#ifndef YMMacro_h
#define YMMacro_h

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) \
    autoreleasepool {}  \
    __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) \
    autoreleasepool {}  \
    __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) \
    try {               \
    } @finally {        \
    }                   \
    {}                  \
    __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) \
    try {               \
    } @finally {        \
    }                   \
    {}                  \
    __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) \
    autoreleasepool {}    \
    __typeof__(object) object = weak##_##object;
#else
#define strongify(object) \
    autoreleasepool {}    \
    __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) \
    try {                 \
    } @finally {          \
    }                     \
    __typeof__(object) object = weak##_##object;
#else
#define strongify(object) \
    try {                 \
    } @finally {          \
    }                     \
    __typeof__(object) object = block##_##object;
#endif
#endif
#endif

#define YM_DEFER   \
    EXT_KEYWORDIFY \
    __strong ym_deferBlock_t ym_deferBlock_##__LINE__ __attribute__((cleanup(ym_deferFunc), unused)) = ^

#if defined(DEBUG)
#define EXT_KEYWORDIFY \
    autoreleasepool {}
#else
#define EXT_KEYWORDIFY \
    try {              \
    } @catch (...) {   \
    }
#endif

typedef void (^ym_deferBlock_t)(void);

NS_INLINE void ym_deferFunc(__strong ym_deferBlock_t *blockRef) { (*blockRef)(); }

NS_INLINE void ym_initializeLibcurl() {
    // TODO: throws
    curl_global_init(CURL_GLOBAL_SSL);
}

#endif /* YMMacro_h */
