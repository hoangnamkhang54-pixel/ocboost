#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static CFStringRef const kOCBoostDomain = CFSTR("com.ngminh.ocboost");
static CFStringRef const kOCBoostChangedNotification = CFSTR("com.ngminh.ocboost/settingsChanged");
static id gOCBoostActivity = nil;
static NSString *gOCBoostBundleID = nil;

static id OCBoostCopyPreference(CFStringRef key) {
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, kOCBoostDomain);
    return value ? CFBridgingRelease(value) : nil;
}

static void OCBoostEndActivity(void) {
    if (gOCBoostActivity) {
        @try {
            [[NSProcessInfo processInfo] endActivity:gOCBoostActivity];
        } @catch (__unused NSException *exception) {
            // Defensive: do not let an optimization hint crash the host app.
        }
        gOCBoostActivity = nil;
    }
}

static void OCBoostRefresh(void) {
    if (gOCBoostBundleID.length == 0) return;
    CFPreferencesAppSynchronize(kOCBoostDomain);

    BOOL enabled = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), kOCBoostDomain, NULL);
    NSString *mode = OCBoostCopyPreference(CFSTR("mode"));
    NSArray *focusedApps = OCBoostCopyPreference(CFSTR("focusedBundleIDs"));
    if (![mode isKindOfClass:[NSString class]]) mode = @"smart";
    if (![focusedApps isKindOfClass:[NSArray class]]) focusedApps = @[];

    UIApplication *application = [UIApplication sharedApplication];
    BOOL foreground = application.applicationState == UIApplicationStateActive;
    BOOL selected = [focusedApps containsObject:gOCBoostBundleID];
    BOOL shouldHint = enabled && foreground && selected &&
                      ([mode isEqualToString:@"maximum"] || [mode isEqualToString:@"smart"]);

    // Smart mode avoids the additional hint when the device is already warm/hot.
    if (shouldHint && [mode isEqualToString:@"smart"]) {
        if (@available(iOS 11.0, *)) {
            NSProcessInfoThermalState state = [NSProcessInfo processInfo].thermalState;
            if (state > NSProcessInfoThermalStateFair) shouldHint = NO;
        }
    }

    if (shouldHint && !gOCBoostActivity) {
        @try {
            // This is only a cooperative scheduling/activity hint. It does not overclock CPU/GPU
            // or reserve all RAM; iOS remains responsible for power and thermal management.
            gOCBoostActivity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep
                                                                               reason:@"OCBoost focused app"];
        } @catch (__unused NSException *exception) {
            gOCBoostActivity = nil;
        }
    } else if (!shouldHint) {
        OCBoostEndActivity();
    }
}

static void OCBoostDarwinChanged(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                 const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{ OCBoostRefresh(); });
}

static void OCBoostApplicationBecameActive(__unused NSNotification *notification) {
    OCBoostRefresh();
}

static void OCBoostApplicationWillResign(__unused NSNotification *notification) {
    OCBoostEndActivity();
}

__attribute__((constructor)) static void OCBoostInit(void) {
    @autoreleasepool {
        // Skip processes without a UIKit app and Apple system processes. This keeps the tweak
        // away from daemons and SpringBoard rather than terminating system services.
        if (NSClassFromString(@"UIApplication") == Nil) return;
        NSDictionary *info = [NSBundle mainBundle].infoDictionary;
        if (info[@"NSExtension"] != nil) return;
        NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
        if (bundleID.length == 0 || [bundleID hasPrefix:@"com.apple."]) return;
        gOCBoostBundleID = [bundleID copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notifications = [NSNotificationCenter defaultCenter];
            [notifications addObserverForName:UIApplicationDidBecomeActiveNotification
                                       object:nil queue:nil usingBlock:^(NSNotification *note) {
                (void)note; OCBoostApplicationBecameActive(nil);
            }];
            [notifications addObserverForName:UIApplicationWillResignActiveNotification
                                       object:nil queue:nil usingBlock:^(NSNotification *note) {
                (void)note; OCBoostApplicationWillResign(nil);
            }];
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                            OCBoostDarwinChanged, kOCBoostChangedNotification,
                                            NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
            OCBoostRefresh();
        });
    }
}
