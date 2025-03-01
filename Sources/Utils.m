#import "Utils.h"
#import "LoaderConfig.h"
#import "Logger.h"
#import <objc/message.h>
#import <spawn.h>
#import <sys/utsname.h>

extern id gBridge;

BOOL isJailbroken = NO;

NSURL *getPyoncordDirectory(void) {
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL = [[fileManager URLsForDirectory:NSDocumentDirectory
                                                       inDomains:NSUserDomainMask] lastObject];

    NSURL *pyoncordFolderURL = [documentDirectoryURL URLByAppendingPathComponent:@"pyoncord"];

    if (![fileManager fileExistsAtPath:pyoncordFolderURL.path]) {
        [fileManager createDirectoryAtURL:pyoncordFolderURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    }

    return pyoncordFolderURL;
}

UIColor *hexToUIColor(NSString *hex) {
    if (![hex hasPrefix:@"#"]) {
        return nil;
    }

    NSString *hexColor = [hex substringFromIndex:1];
    if (hexColor.length == 6) {
        hexColor = [hexColor stringByAppendingString:@"ff"];
    }

    if (hexColor.length == 8) {
        unsigned int hexNumber;
        NSScanner *scanner = [NSScanner scannerWithString:hexColor];
        if ([scanner scanHexInt:&hexNumber]) {
            CGFloat r = ((hexNumber & 0xFF000000) >> 24) / 255.0;
            CGFloat g = ((hexNumber & 0x00FF0000) >> 16) / 255.0;
            CGFloat b = ((hexNumber & 0x0000FF00) >> 8) / 255.0;
            CGFloat a = (hexNumber & 0x000000FF) / 255.0;

            return [UIColor colorWithRed:r green:g blue:b alpha:a];
        }
    }

    return nil;
}

void showErrorAlert(NSString *title, NSString *message, void (^completion)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:title
                                                message:message
                                         preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             if (completion) {
                                                                 completion();
                                                             }
                                                         }];

        [alert addAction:okAction];

        UIWindow *window = nil;
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for (UIWindow *w in windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }

        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

NSString *getDeviceIdentifier(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

void reloadApp(UIViewController *viewController) {
    [viewController
        dismissViewControllerAnimated:NO
                           completion:^{
                               if (gBridge &&
                                   [gBridge isKindOfClass:NSClassFromString(@"RCTCxxBridge")]) {
                                   SEL reloadSelector = NSSelectorFromString(@"reload");
                                   if ([gBridge respondsToSelector:reloadSelector]) {
                                       ((void (*)(id, SEL))objc_msgSend)(gBridge, reloadSelector);
                                       return;
                                   }
                               }

                               UIApplication *app = [UIApplication sharedApplication];
                               ((void (*)(id, SEL))objc_msgSend)(app, @selector(suspend));
                               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                                              dispatch_get_main_queue(), ^{ exit(0); });
                           }];
}

void loadCustomBundleFromURL(NSURL *url, UIViewController *viewController) {
    LoaderConfig *config        = [LoaderConfig getLoaderConfig];
    config.customLoadUrlEnabled = YES;
    config.customLoadUrl        = url;
    if ([config saveConfig]) {
        reloadApp(viewController);
    } else {
        showErrorAlert(@"Error", @"Failed to save custom bundle configuration", nil);
    }
}

void deletePlugins(void) {
    [[NSFileManager defaultManager]
        removeItemAtURL:[getPyoncordDirectory() URLByAppendingPathComponent:@"plugins"]
                  error:nil];
}

void deleteThemes(void) {
    [[NSFileManager defaultManager]
        removeItemAtURL:[getPyoncordDirectory() URLByAppendingPathComponent:@"themes"]
                  error:nil];
}

void deleteAllData(UIViewController *presenter) {
    [[NSFileManager defaultManager] removeItemAtURL:getPyoncordDirectory() error:nil];
    gracefulExit(presenter);
}

void gracefulExit(UIViewController *presenter) {
    UIApplication *app = [UIApplication sharedApplication];
    [app performSelector:@selector(suspend)];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(),
                   ^{ [app performSelector:@selector(terminateWithSuccess)]; });
}

void setCustomBundleURL(NSURL *url, UIViewController *presenter) {
    LoaderConfig *config        = [LoaderConfig getLoaderConfig];
    config.customLoadUrlEnabled = YES;
    config.customLoadUrl        = url;
    [config saveConfig];
    removeCachedBundle();
    gracefulExit(presenter);
}

void resetCustomBundleURL(UIViewController *presenter) {
    LoaderConfig *config        = [LoaderConfig getLoaderConfig];
    config.customLoadUrlEnabled = NO;
    config.customLoadUrl        = [NSURL URLWithString:@"http://localhost:4040/bunny.js"];
    [config saveConfig];
    removeCachedBundle();
    gracefulExit(presenter);
}

BOOL isSafeModeEnabled(void) {
    NSURL *documentDirectoryURL =
        [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask]
            .lastObject;
    NSURL *settingsURL =
        [documentDirectoryURL URLByAppendingPathComponent:@"vd_mmkv/VENDETTA_SETTINGS"];

    NSData *data = [NSData dataWithContentsOfURL:settingsURL];
    if (!data)
        return NO;

    NSError *error         = nil;
    NSDictionary *settings = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error)
        return NO;

    return [settings[@"safeMode"][@"enabled"] boolValue];
}

void toggleSafeMode(void) {
    NSURL *documentDirectoryURL =
        [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask]
            .lastObject;
    NSURL *settingsURL =
        [documentDirectoryURL URLByAppendingPathComponent:@"vd_mmkv/VENDETTA_SETTINGS"];
    NSURL *themeURL = [documentDirectoryURL URLByAppendingPathComponent:@"vd_mmkv/VENDETTA_THEMES"];

    NSData *data                  = [NSData dataWithContentsOfURL:settingsURL];
    NSMutableDictionary *settings = nil;

    if (data) {
        settings = [[NSJSONSerialization JSONObjectWithData:data
                                                    options:NSJSONReadingMutableContainers
                                                      error:nil] mutableCopy];
    } else {
        settings = [NSMutableDictionary dictionary];
    }

    if (!settings[@"safeMode"]) {
        settings[@"safeMode"] = [NSMutableDictionary dictionary];
    }

    BOOL currentState                 = [settings[@"safeMode"][@"enabled"] boolValue];
    BOOL newState                     = !currentState;
    settings[@"safeMode"][@"enabled"] = @(newState);

    NSData *themeData = [NSData dataWithContentsOfURL:themeURL];
    if (themeData) {
        NSDictionary *theme = [NSJSONSerialization JSONObjectWithData:themeData
                                                              options:0
                                                                error:nil];
        if (theme && theme[@"id"]) {
            if (newState) {
                settings[@"safeMode"][@"currentThemeId"] = theme[@"id"];
                [[NSFileManager defaultManager] removeItemAtURL:themeURL error:nil];
            }
        }
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:settings options:0 error:nil];
    [jsonData writeToURL:settingsURL atomically:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC), dispatch_get_main_queue(),
                   ^{
                       UIViewController *rootVC =
                           [UIApplication sharedApplication].windows.firstObject.rootViewController;
                       reloadApp(rootVC);
                   });
}

static void showCommitsForBranch(NSString *branch, UIViewController *presenter,
                                 NSURLSession *session);

void showBundleSelector(UIViewController *presenter) {
    BunnyLog(@"Starting bundle selector...");

    UIAlertController *loadingAlert =
        [UIAlertController alertControllerWithTitle:@"Loading"
                                            message:@"Fetching branches..."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:loadingAlert animated:YES completion:nil];

    NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/bunny-mod/builds/branches"];
    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    BunnyLog(@"Fetching branches from: %@", url);

    [[session
          dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loadingAlert
                    dismissViewControllerAnimated:YES
                                       completion:^{
                                           if (error || !data) {
                                               showErrorAlert(@"Error", @"Failed to fetch branches",
                                                              nil);
                                               return;
                                           }

                                           NSError *jsonError;
                                           NSArray *branches =
                                               [NSJSONSerialization JSONObjectWithData:data
                                                                               options:0
                                                                                 error:&jsonError];
                                           if (jsonError || !branches.count) {
                                               showErrorAlert(@"Error", @"No branches available",
                                                              nil);
                                               return;
                                           }

                                           UIAlertController *branchAlert = [UIAlertController
                                               alertControllerWithTitle:@"Select Branch"
                                                                message:nil
                                                         preferredStyle:
                                                             UIAlertControllerStyleAlert];

                                           for (NSDictionary *branch in branches) {
                                               NSString *branchName = branch[@"name"];
                                               [branchAlert
                                                   addAction:
                                                       [UIAlertAction
                                                           actionWithTitle:branchName
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(
                                                                       UIAlertAction *action) {
                                                                       showCommitsForBranch(
                                                                           branchName, presenter,
                                                                           session);
                                                                   }]];
                                           }

                                           [branchAlert
                                               addAction:
                                                   [UIAlertAction
                                                       actionWithTitle:@"Cancel"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil]];

                                           [presenter presentViewController:branchAlert
                                                                   animated:YES
                                                                 completion:nil];
                                       }];
            });
        }] resume];
}

static void showCommitsForBranch(NSString *branch, UIViewController *presenter,
                                 NSURLSession *session) {
    BunnyLog(@"Fetching commits for branch: %@", branch);

    UIAlertController *loadingCommits =
        [UIAlertController alertControllerWithTitle:@"Loading"
                                            message:@"Fetching commits..."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:loadingCommits animated:YES completion:nil];

    NSString *commitsUrl = [NSString
        stringWithFormat:
            @"https://api.github.com/repos/bunny-mod/builds/commits?sha=%@&per_page=10", branch];
    NSURL *commitsURL    = [NSURL URLWithString:commitsUrl];

    [[session
          dataTaskWithURL:commitsURL
        completionHandler:^(NSData *commitsData, NSURLResponse *commitsResponse,
                            NSError *commitsError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loadingCommits
                    dismissViewControllerAnimated:YES
                                       completion:^{
                                           if (commitsError || !commitsData) {
                                               showErrorAlert(@"Error", @"Failed to fetch commits",
                                                              nil);
                                               return;
                                           }

                                           NSError *jsonError;
                                           NSArray *commits =
                                               [NSJSONSerialization JSONObjectWithData:commitsData
                                                                               options:0
                                                                                 error:&jsonError];
                                           if (jsonError || !commits.count) {
                                               showErrorAlert(@"Error", @"No commits available",
                                                              nil);
                                               return;
                                           }

                                           UIAlertController *commitAlert = [UIAlertController
                                               alertControllerWithTitle:@"Select Version"
                                                                message:nil
                                                         preferredStyle:
                                                             UIAlertControllerStyleAlert];

                                           for (NSDictionary *commit in commits) {
                                               NSString *sha = commit[@"sha"];
                                               NSString *dateStr =
                                                   commit[@"commit"][@"author"][@"date"];

                                               NSDateFormatter *iso8601Formatter =
                                                   [[NSDateFormatter alloc] init];
                                               iso8601Formatter.dateFormat =
                                                   @"yyyy-MM-dd'T'HH:mm:ssZ";
                                               NSDate *date =
                                                   [iso8601Formatter dateFromString:dateStr];

                                               NSDateFormatter *formatter =
                                                   [[NSDateFormatter alloc] init];
                                               formatter.dateFormat = @"MMM d, yyyy";

                                               NSString *title = [NSString
                                                   stringWithFormat:@"%@ (%@)",
                                                                    [sha substringToIndex:7],
                                                                    [formatter
                                                                        stringFromDate:date]];

                                               [commitAlert
                                                   addAction:
                                                       [UIAlertAction
                                                           actionWithTitle:title
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(
                                                                       UIAlertAction *action) {
                                                                       NSString *bundleUrl =
                                                                           [NSString
                                                                               stringWithFormat:
                                                                                   @"https://"
                                                                                   @"raw."
                                                                                   @"githubusercont"
                                                                                   @"ent.com/"
                                                                                   @"bunny-mod/"
                                                                                   @"builds/%@/"
                                                                                   @"bunny.min.js",
                                                                                   sha];
                                                                       NSURL *url = [NSURL
                                                                           URLWithString:bundleUrl];
                                                                       setCustomBundleURL(
                                                                           url, presenter);
                                                                       reloadApp(presenter);
                                                                   }]];
                                           }

                                           [commitAlert
                                               addAction:
                                                   [UIAlertAction
                                                       actionWithTitle:@"Cancel"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil]];

                                           [presenter presentViewController:commitAlert
                                                                   animated:YES
                                                                 completion:nil];
                                       }];
            });
        }] resume];
}

void removeCachedBundle(void) {
    NSURL *bundleURL = [getPyoncordDirectory() URLByAppendingPathComponent:@"bundle.js"];
    NSError *error   = nil;
    [[NSFileManager defaultManager] removeItemAtURL:bundleURL error:&error];
    if (error) {
        BunnyLog(@"Failed to remove cached bundle: %@", error);
    }
}

void refetchBundle(UIViewController *presenter) {
    removeCachedBundle();
    gracefulExit(presenter);
}

void deletePluginsAndReload(UIViewController *presenter) {
    deletePlugins();
    reloadApp(presenter);
}

void deleteThemesAndReload(UIViewController *presenter) {
    deleteThemes();
    reloadApp(presenter);
}
