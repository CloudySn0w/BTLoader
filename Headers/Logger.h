#import <Foundation/Foundation.h>

#define LOG_PREFIX         @"[BTLoader]"
#define BTLoaderLog(fmt, ...) NSLog((LOG_PREFIX @" " fmt), ##__VA_ARGS__)
