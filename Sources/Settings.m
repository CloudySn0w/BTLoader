#import "Settings.h"
#import "DeviceModels.h"
#import "Logger.h"
#import "Utils.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation BTLoaderSettingsViewController

- (instancetype)initWithVersion:(NSString *)version {
    self = [super init];
    if (self) {
        self.title = [NSString stringWithFormat:@"BTLoader v%@ Recovery Menu", version];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                          style:UITableViewStyleInsetGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate                                  = self;
    tableView.dataSource                                = self;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"Cell"];
    }

    NSArray *options = @[
        @{@"title" : @"Toggle Safe Mode", @"icon" : @"shield", @"destructive" : @NO}, @{
            @"title" : @"Refetch Bundle",
            @"icon" : @"arrow.triangle.2.circlepath",
            @"destructive" : @NO
        },
        @{
            @"title" : @"Switch Bundle Version",
            @"icon" : @"arrow.triangle.2.circlepath.circle",
            @"destructive" : @NO
        },
        @{@"title" : @"Load Custom Bundle", @"icon" : @"link.badge.plus", @"destructive" : @NO},
        @{@"title" : @"Reset Bundle", @"icon" : @"arrow.counterclockwise", @"destructive" : @YES},
        @{@"title" : @"Delete All Plugins", @"icon" : @"trash", @"destructive" : @YES},
        @{@"title" : @"Delete All Themes", @"icon" : @"trash", @"destructive" : @YES},
        @{@"title" : @"Delete All Mod Data", @"icon" : @"trash.fill", @"destructive" : @YES},
        @{@"title" : @"Open App Folder", @"icon" : @"folder", @"destructive" : @NO}, @{
            @"title" : @"Open GitHub Issue",
            @"icon" : @"exclamationmark.bubble",
            @"destructive" : @NO
        }
    ];

    NSDictionary *option = options[indexPath.row];
    cell.textLabel.text  = option[@"title"];

    UIImageConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:22
                                                        weight:UIImageSymbolWeightRegular];
    UIImage *icon        = [UIImage systemImageNamed:option[@"icon"] withConfiguration:config];
    cell.imageView.image = icon;
    cell.imageView.tintColor =
        [option[@"destructive"] boolValue] ? UIColor.systemRedColor : UIColor.systemBlueColor;

    if (indexPath.row == 0) {
        cell.textLabel.text = isSafeModeEnabled() ? @"Disable Safe Mode" : @"Enable Safe Mode";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row == 0) {
        toggleSafeMode();
        return;
    }

    if (indexPath.row == 2) {
        showBundleSelector(self);
        return;
    }

    void (^performAction)(void) = ^{
        switch (indexPath.row) {
        case 1:
            refetchBundle(self);
            break;
        case 3:
            [self loadCustomBundle];
            break;
        case 4:
            resetCustomBundleURL(self);
            break;
        case 5:
            deletePluginsAndReload(self);
            break;
        case 6:
            deleteThemesAndReload(self);
            break;
        case 7:
            deleteAllData(self);
            break;
        case 8:
            [self openDocumentsDirectory];
            break;
        case 9:
            [self openGitHub];
            break;
        }
    };

    if (indexPath.row != 3 && indexPath.row != 8 && indexPath.row != 9) {
        NSString *actionText;
        switch (indexPath.row) {
        case 1:
            actionText = @"refetch the bundle";
            break;
        case 4:
            actionText = @"reset the bundle";
            break;
        case 5:
            actionText = @"delete all plugins";
            break;
        case 6:
            actionText = @"delete all themes";
            break;
        case 7:
            actionText = @"delete all mod data";
            break;
        default:
            actionText = @"perform this action";
            break;
        }

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Confirm Action"
                             message:[NSString stringWithFormat:@"Are you sure you want to %@?",
                                                                actionText]
                      preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [alert addAction:[UIAlertAction
                             actionWithTitle:@"Confirm"
                                       style:UIAlertActionStyleDestructive
                                     handler:^(UIAlertAction *action) { performAction(); }]];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        performAction();
    }
}

- (void)openDocumentsDirectory {
    if (isJailbroken) {
        NSString *filzaPath = [NSString stringWithFormat:@"filza://view%@", getPyoncordDirectory().path];
        NSURL *filzaURL = [NSURL URLWithString:[filzaPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
        if ([[UIApplication sharedApplication] canOpenURL:filzaURL]) {
            [[UIApplication sharedApplication] openURL:filzaURL options:@{} completionHandler:nil];
            return;
        }
    }
    
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsUrl = [paths firstObject];
    
    NSString *sharedPath = [NSString stringWithFormat:@"shareddocuments://%@", documentsUrl.path];
    NSURL *sharedUrl = [NSURL URLWithString:sharedPath];
    
    [[UIApplication sharedApplication] openURL:sharedUrl options:@{} completionHandler:nil];
}

- (void)openGitHub {
    UIDevice *device      = [UIDevice currentDevice];
    NSString *deviceId    = getDeviceIdentifier();
    NSString *deviceModel = DEVICE_MODELS[deviceId] ?: deviceId;
    NSString *appVersion =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

    NSString *body =
        [NSString stringWithFormat:@"### Device Information\n"
                                    "- Device: %@\n"
                                    "- iOS Version: %@\n"
                                    "- Tweak Version: %@\n"
                                    "- App Version: %@ (%@)\n"
                                    "- Jailbroken: %@\n\n"
                                    "### Issue Description\n"
                                    "<!-- Describe your issue here -->\n\n"
                                    "### Steps to Reproduce\n"
                                    "1. \n2. \n3. \n\n"
                                    "### Expected Behavior\n\n"
                                    "### Actual Behavior\n",
                                   deviceModel, device.systemVersion, PACKAGE_VERSION, appVersion,
                                   buildNumber, isJailbroken ? @"Yes" : @"No"];

    NSString *encodedTitle = [@"bug(iOS): "
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                               URLQueryAllowedCharacterSet]];
    NSString *encodedBody =
        [body stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                                     URLQueryAllowedCharacterSet]];

    NSString *urlString = [NSString
        stringWithFormat:@"https://github.com/CloudySn0w/BTLoader/issues/new",
                         encodedTitle, encodedBody];
    NSURL *url          = [NSURL URLWithString:urlString];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)loadCustomBundle {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Load Custom Bundle"
                                            message:@"Enter the URL for your custom bundle:"
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder            = @"https://example.com/bundle.js";
        textField.keyboardType           = UIKeyboardTypeURL;
        textField.autocorrectionType     = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    UIAlertAction *loadAction = [UIAlertAction
        actionWithTitle:@"Load"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    NSString *urlString = alert.textFields.firstObject.text;
                    if (urlString.length == 0) {
                        [self presentViewController:alert animated:YES completion:nil];
                        showErrorAlert(@"Invalid URL", @"Please enter a URL", nil);
                        return;
                    }

                    NSURL *url = [NSURL URLWithString:urlString];
                    if (!url || !url.scheme || !url.host) {
                        [self presentViewController:alert animated:YES completion:nil];
                        showErrorAlert(
                            @"Invalid URL",
                            @"Please enter a valid URL (e.g., https://example.com/bundle.js)", nil);
                        return;
                    }

                    if (![url.scheme isEqualToString:@"http"] &&
                        ![url.scheme isEqualToString:@"https"]) {
                        [self presentViewController:alert animated:YES completion:nil];
                        showErrorAlert(@"Invalid URL", @"URL must start with http:// or https://",
                                       nil);
                        return;
                    }

                    NSURLSession *session =
                        [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration
                                                                   defaultSessionConfiguration]];
                    [[session
                          dataTaskWithURL:url
                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (error) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(
                                        @"Connection Error",
                                        [NSString stringWithFormat:@"Could not reach URL: %@",
                                                                   error.localizedDescription],
                                        nil);
                                    return;
                                }

                                if (!data) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(@"Error", @"No data received from URL", nil);
                                    return;
                                }

                                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                if (httpResponse.statusCode != 200) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(
                                        @"Error",
                                        [NSString stringWithFormat:@"Server returned error %ld",
                                                                   (long)httpResponse.statusCode],
                                        nil);
                                    return;
                                }

                                NSString *contentType =
                                    httpResponse.allHeaderFields[@"Content-Type"];
                                if (![contentType containsString:@"javascript"] &&
                                    ![contentType containsString:@"text"]) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(@"Invalid Content",
                                                   @"URL must point to a JavaScript file", nil);
                                    return;
                                }

                                setCustomBundleURL(url, self);
                                removeCachedBundle();
                                gracefulExit(self);
                            });
                        }] resume];
                }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:loadAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

void showSettingsSheet(void) {
    BTLoaderSettingsViewController *settingsVC =
        [[BTLoaderSettingsViewController alloc] initWithVersion:PACKAGE_VERSION];

    UINavigationController *navController =
        [[UINavigationController alloc] initWithRootViewController:settingsVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;

    UIBarButtonItem *doneButton =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:settingsVC
                                                      action:@selector(dismiss)];
    settingsVC.navigationItem.rightBarButtonItem = doneButton;

    UIWindow *window = nil;
    NSSet *scenes    = [[UIApplication sharedApplication] connectedScenes];
    for (UIScene *scene in scenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = ((UIWindowScene *)scene).windows.firstObject;
            break;
        }
    }

    if (!window) {
        window = [[UIApplication sharedApplication] windows].firstObject;
    }

    if (window && window.rootViewController) {
        [window.rootViewController presentViewController:navController animated:YES completion:nil];
    }
}

@end
