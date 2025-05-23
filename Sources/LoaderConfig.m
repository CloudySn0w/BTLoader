#import "LoaderConfig.h"
#import "Logger.h"
#import "Utils.h"

@implementation LoaderConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        self.customLoadUrlEnabled = NO;
        self.customLoadUrl        = [NSURL URLWithString:@"http://localhost:4040/btloader.js"];
    }
    return self;
}

- (BOOL)loadConfig {
    NSURL *loaderConfigUrl = [getPyoncordDirectory() URLByAppendingPathComponent:@"loader.json"];
    BTLoaderLog(@"Attempting to load config from: %@", loaderConfigUrl.path);

    if ([[NSFileManager defaultManager] fileExistsAtPath:loaderConfigUrl.path]) {
        NSError *error     = nil;
        NSData *data       = [NSData dataWithContentsOfURL:loaderConfigUrl];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

        if (error) {
            BTLoaderLog(@"Error parsing loader config: %@", error);
            return NO;
        }

        if (json) {
            NSDictionary *customLoadUrl = json[@"customLoadUrl"];
            if (customLoadUrl) {
                self.customLoadUrlEnabled = [customLoadUrl[@"enabled"] boolValue];
                NSString *urlString       = customLoadUrl[@"url"];
                if (urlString) {
                    self.customLoadUrl = [NSURL URLWithString:urlString];
                }
            }

            BTLoaderLog(@"Loader config loaded - Custom URL %@: %@",
                     self.customLoadUrlEnabled ? @"enabled" : @"disabled",
                     self.customLoadUrl.absoluteString);
            return YES;
        }
    }

    BTLoaderLog(@"Using default loader config: %@", self.customLoadUrl.absoluteString);
    return NO;
}

+ (instancetype)defaultConfig {
    LoaderConfig *config        = [[LoaderConfig alloc] init];
    config.customLoadUrlEnabled = NO;
    config.customLoadUrl        = [NSURL URLWithString:@"http://localhost:4040/btloader.js"];
    return config;
}

+ (instancetype)getLoaderConfig {
    BTLoaderLog(@"Getting loader config");

    NSURL *loaderConfigUrl = [getPyoncordDirectory() URLByAppendingPathComponent:@"loader.json"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:loaderConfigUrl.path]) {
        NSError *error     = nil;
        NSData *data       = [NSData dataWithContentsOfURL:loaderConfigUrl];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

        if (json && !error) {
            LoaderConfig *config        = [[LoaderConfig alloc] init];
            NSDictionary *customLoadUrl = json[@"customLoadUrl"];
            if (customLoadUrl) {
                config.customLoadUrlEnabled = [customLoadUrl[@"enabled"] boolValue];
                NSString *urlString         = customLoadUrl[@"url"];
                if (urlString) {
                    config.customLoadUrl = [NSURL URLWithString:urlString];
                }
            }
            return config;
        }
    }

    BTLoaderLog(@"Couldn't get loader config");
    return [LoaderConfig defaultConfig];
}

- (BOOL)saveConfig {
    NSURL *loaderConfigUrl = [getPyoncordDirectory() URLByAppendingPathComponent:@"loader.json"];
    NSDictionary *json     = @{
        @"customLoadUrl" :
            @{@"enabled" : @(self.customLoadUrlEnabled), @"url" : self.customLoadUrl.absoluteString}
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    return [data writeToURL:loaderConfigUrl atomically:YES];
}

@end
