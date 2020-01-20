#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "YMEasyHandle.h"
#import "YMMacro.h"
#import "YMMultiHandle.h"
#import "YMTimeoutSource.h"
#import "curl.h"
#import "curlver.h"
#import "easy.h"
#import "mprintf.h"
#import "multi.h"
#import "stdcheaders.h"
#import "system.h"
#import "typecheck-gcc.h"

FOUNDATION_EXPORT double YMHTTPVersionNumber;
FOUNDATION_EXPORT const unsigned char YMHTTPVersionString[];

