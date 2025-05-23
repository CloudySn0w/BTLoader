#import <AuthenticationServices/AuthenticationServices.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dlfcn.h>

#import "Logger.h"
#import "Utils.h"

typedef struct __CMSDecoder *CMSDecoderRef;
extern CFTypeRef             SecCMSDecodeGetContent(CFDataRef message);
extern OSStatus              CMSDecoderCreate(CMSDecoderRef *cmsDecoder);
extern OSStatus              CMSDecoderUpdateMessage(CMSDecoderRef cmsDecoder, const void *content,
                                                     size_t contentLength);
extern OSStatus              CMSDecoderFinalizeMessage(CMSDecoderRef cmsDecoder);
extern OSStatus              CMSDecoderCopyContent(CMSDecoderRef cmsDecoder, CFDataRef *content);

#define DISCORD_BUNDLE_ID @"com.hammerandchisel.discord"
#define DISCORD_NAME      @"Discord"

typedef NS_ENUM(NSInteger, BundleIDError) {
    BundleIDErrorIcon,
    BundleIDErrorPasskey
};

static void showBundleIDError(BundleIDError error)
{
    NSString *message;
    NSString *title;
    void (^completion)(void) = nil;

    switch (error)
    {
        case BundleIDErrorIcon:
            message = @"For this to work change the Bundle ID so that it matches your "
                      @"provisioning profile's App ID (excluding the Team ID prefix).";
            title   = @"Cannot Change Icon";
            break;
        case BundleIDErrorPasskey:
            message    = @"Passkeys are not supported when sideloading Discord. "
                         @"Please use a different login method.";
            title      = @"Cannot Use Passkey";
            completion = ^{ exit(0); };
            break;
    }

    showErrorAlert(title, message, completion);
}

static NSString *getAccessGroupID(void)
{
    NSDictionary *query = @{
        (__bridge NSString *) kSecClass : (__bridge NSString *) kSecClassGenericPassword,
        (__bridge NSString *) kSecAttrAccount : @"bundleSeedID",
        (__bridge NSString *) kSecAttrService : @"",
        (__bridge NSString *) kSecReturnAttributes : @YES
    };

    CFDictionaryRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef *) &result);

    if (status == errSecItemNotFound)
    {
        status = SecItemAdd((__bridge CFDictionaryRef) query, (CFTypeRef *) &result);
    }

    if (status != errSecSuccess)
        return nil;

    NSString *accessGroup =
        [(__bridge NSDictionary *) result objectForKey:(__bridge NSString *) kSecAttrAccessGroup];
    if (result)
        CFRelease(result);

    return accessGroup;
}

static BOOL isSelfCall(void)
{
    NSArray *address = [NSThread callStackReturnAddresses];
    Dl_info  info    = {0};
    if (dladdr((void *) [address[2] longLongValue], &info) == 0)
        return NO;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    return [path hasPrefix:NSBundle.mainBundle.bundlePath];
}

%group Sideloading

%hook NSBundle
- (NSString *)bundleIdentifier
{
    return isSelfCall() ? DISCORD_BUNDLE_ID : %orig;
}

- (NSDictionary *)infoDictionary
{
    if (!isSelfCall())
        return %orig;

    NSMutableDictionary *info    = [%orig mutableCopy];
    info[@"CFBundleIdentifier"]  = DISCORD_BUNDLE_ID;
    info[@"CFBundleDisplayName"] = DISCORD_NAME;
    info[@"CFBundleName"]        = DISCORD_NAME;
    return info;
}

- (id)objectForInfoDictionaryKey:(NSString *)key
{
    if (!isSelfCall())
        return %orig;

    if ([key isEqualToString:@"CFBundleIdentifier"])
        return DISCORD_BUNDLE_ID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"])
        return DISCORD_NAME;
    return %orig;
}
%end

%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    BTLoaderLog(@"containerURLForSecurityApplicationGroupIdentifier called! %@",
             groupIdentifier ?: @"nil");

    NSArray *paths    = [self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL   *lastPath = [paths lastObject];
    return [lastPath URLByAppendingPathComponent:@"AppGroup"];
}
%end

%hook UIPasteboard
- (NSString *)_accessGroup
{
    return getAccessGroupID();
}
%end

%hook UIApplication
- (void)setAlternateIconName:(NSString *)iconName completionHandler:(void (^)(NSError *))completion
{
    void (^wrappedCompletion)(NSError *) = ^(NSError *error) {
        if (error)
        {
            showBundleIDError(BundleIDErrorIcon);
        }

        if (completion)
        {
            completion(error);
        }
    };

    %orig(iconName, wrappedCompletion);
}
%end

// https://github.com/khanhduytran0/LiveContainer/blob/main/TweakLoader/DocumentPicker.m
%hook UIDocumentPickerViewController

- (instancetype)initForOpeningContentTypes:(NSArray<UTType *> *)contentTypes asCopy:(BOOL)asCopy
{
    BOOL shouldMultiselect = NO;
    if ([contentTypes count] == 1 && contentTypes[0] == UTTypeFolder)
    {
        shouldMultiselect = YES;
    }

    NSArray<UTType *> *contentTypesNew = @[ UTTypeItem, UTTypeFolder ];

    UIDocumentPickerViewController *ans = %orig(contentTypesNew, YES);
    if (shouldMultiselect)
    {
        [ans setAllowsMultipleSelection:YES];
    }
    return ans;
}

- (instancetype)initWithDocumentTypes:(NSArray<UTType *> *)contentTypes inMode:(NSUInteger)mode
{
    return [self initForOpeningContentTypes:contentTypes asCopy:(mode == 1 ? NO : YES)];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
    if ([self allowsMultipleSelection])
    {
        return;
    }
    %orig(YES);
}

%end

%hook UIDocumentBrowserViewController

- (instancetype)initForOpeningContentTypes:(NSArray<UTType *> *)contentTypes
{
    NSArray<UTType *> *contentTypesNew = @[ UTTypeItem, UTTypeFolder ];
    return %orig(contentTypesNew);
}

%end

%hook NSURL

- (BOOL)startAccessingSecurityScopedResource
{
    %orig;
    return YES;
}

%end

%hook ASAuthorizationController

- (void)performRequests
{
    showBundleIDError(BundleIDErrorPasskey);
}

%end

%end

%ctor
{
    BOOL isAppStoreApp = [[NSFileManager defaultManager]
        fileExistsAtPath:[[NSBundle mainBundle] appStoreReceiptURL].path];
    if (!isAppStoreApp)
    {
        %init(Sideloading);
    }
}
