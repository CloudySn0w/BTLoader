#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BunnySettingsViewController;

extern BOOL isJailbroken;
BOOL        isSafeModeEnabled(void);
NSURL      *getPyoncordDirectory(void);
UIColor    *hexToUIColor(NSString *hex);
NSString   *getDeviceIdentifier(void);
void        showErrorAlert(NSString *title, NSString *message, void (^completion)(void));
void        reloadApp(UIViewController *viewController);
void        deletePlugins(void);
void        deleteThemes(void);
void        deleteAllData(UIViewController *presenter);
void        refetchBundle(UIViewController *presenter);
void        toggleSafeMode(void);
void        setCustomBundleURL(NSURL *url, UIViewController *presenter);
void        resetCustomBundleURL(UIViewController *presenter);
void        showBundleSelector(UIViewController *presenter);
void        removeCachedBundle(void);
void        gracefulExit(UIViewController *presenter);
void        deletePluginsAndReload(UIViewController *presenter);
void        deleteThemesAndReload(UIViewController *presenter);
