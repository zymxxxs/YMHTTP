//
//  YMMacro.h
//  YMHTTP
//
//  Created by zymxxxs on 2020/1/3.
//

#import <Foundation/Foundation.h>

#ifndef YMMacro_h
#define YMMacro_h

#define YM_DEFER \
EXT_KEYWORDIFY \
__strong ym_deferBlock_t ym_deferBlock_##__LINE__ __attribute__((cleanup(ym_deferFunc), unused)) = ^


#if defined(DEBUG)
#define EXT_KEYWORDIFY autoreleasepool {}
#else
#define EXT_KEYWORDIFY try {} @catch (...) {}
#endif

typedef void (^ym_deferBlock_t)(void);

NS_INLINE void ym_deferFunc(__strong ym_deferBlock_t *blockRef)
{
    (*blockRef)();
}


#endif /* YMMacro_h */
