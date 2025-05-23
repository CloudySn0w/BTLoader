#import "Themes.h"

static NSDictionary *gSemanticColors = nil;
static NSDictionary *gRawColors      = nil;
static NSMutableSet *loggedColors    = nil;

static NSInteger getThemeIndex(void) {
    Class DCDTheme = NSClassFromString(@"DCDTheme");
    if (!DCDTheme)
        return 0;

    SEL themeIndexSelector = NSSelectorFromString(@"themeIndex");
    if (![DCDTheme respondsToSelector:themeIndexSelector])
        return 0;

    typedef NSInteger (*ThemeIndexFunc)(id, SEL);
    return ((ThemeIndexFunc)objc_msgSend)(DCDTheme, themeIndexSelector);
}

static NSString *camelToSnakeCase(NSString *input) {
    NSMutableString *output   = [NSMutableString string];
    NSCharacterSet *uppercase = [NSCharacterSet uppercaseLetterCharacterSet];

    for (NSUInteger i = 0; i < input.length; i++) {
        unichar c = [input characterAtIndex:i];
        if (i > 0 && [uppercase characterIsMember:c]) {
            [output appendString:@"_"];
        }
        [output appendFormat:@"%c", toupper(c)];
    }
    return output;
}

static void swizzleRawColorMethods(void) {
    Class targetClass = [UIColor class];
    if (!targetClass)
        return;

    BTLoaderLog(@"Processing %lu raw color methods", (unsigned long)gRawColors.count);

    for (NSString *key in gRawColors) {
        SEL selector          = NSSelectorFromString(key);
        Method existingMethod = class_getClassMethod(targetClass, selector);

        IMP implementation = imp_implementationWithBlock(^UIColor *(id self) {
            NSString *hexColor = gRawColors[key];
            UIColor *color     = hexToUIColor(hexColor);
            if (color && ![loggedColors containsObject:key]) {
                [loggedColors addObject:key];
                BTLoaderLog(@"Applied raw color: %@ -> %@", key, hexColor);
            }
            return color ?: [UIColor clearColor];
        });

        if (existingMethod) {
            method_setImplementation(existingMethod, implementation);
        } else {
            class_addMethod(object_getClass(targetClass), selector, implementation, "@16@0:8");
        }
    }
}

static void swizzleDCDThemeColorMethods(void) {
    Class targetClass = objc_getClass("DCDThemeColor");
    if (!targetClass)
        return;

    unsigned int methodCount = 0;
    Method *methods          = class_copyMethodList(object_getClass(targetClass), &methodCount);
    if (!methods)
        return;

    BTLoaderLog(@"Processing %lu semantic color methods", (unsigned long)gSemanticColors.count);
    loggedColors = [NSMutableSet new];

    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        char returnType[256];
        method_getReturnType(method, returnType, sizeof(returnType));
        if (strcmp(returnType, @encode(UIColor *)) != 0)
            continue;

        SEL selector   = method_getName(method);
        NSString *name = NSStringFromSelector(selector);
        IMP original   = method_getImplementation(method);

        IMP replacement = imp_implementationWithBlock(^UIColor *(id self) {
            NSString *snakeKey = camelToSnakeCase(name);
            NSArray *colors    = gSemanticColors[snakeKey];

            if (colors && [colors isKindOfClass:[NSArray class]]) {
                NSInteger themeIndex = getThemeIndex();
                if (themeIndex < colors.count) {
                    UIColor *color = hexToUIColor(colors[themeIndex]);
                    if (color) {
                        if (![loggedColors containsObject:name]) {
                            [loggedColors addObject:name];
                            BTLoaderLog(@"Applied theme color: %@ -> %@", name, colors[themeIndex]);
                        }
                        return color;
                    }
                }
            }
            return ((UIColor * (*)(id, SEL)) original)(self, selector);
        });

        method_setImplementation(method, replacement);
    }

    free(methods);
}

void initializeThemeColors(NSDictionary *semanticColors, NSDictionary *rawColors) {
    if (!semanticColors || !rawColors)
        return;

    BTLoaderLog(@"Initializing theme (%lu semantic colors, %lu raw colors)",
             (unsigned long)semanticColors.count, (unsigned long)rawColors.count);

    gSemanticColors = [semanticColors copy];
    gRawColors      = [rawColors copy];
    loggedColors    = [NSMutableSet new];

    swizzleDCDThemeColorMethods();
    swizzleRawColorMethods();
}
