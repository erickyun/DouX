#import "TikTokHeaders.h"
#import "DouXLoginDiagnostics.h"
#import <objc/runtime.h>
#import <objc/message.h>

static void DouXInstallDelegateProbes(id delegate);
static void DouXInstallSceneProbes(id delegate);
static void DouXInstallCurrentCallbackProbes(void);

static NSString * const kDouXLoginEventsKey = @"doux_login_diagnostic_events";
static NSString * const kDouXLoginEnabledKey = @"login_diagnostics";

static BOOL DouXLoginDiagnosticsEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kDouXLoginEnabledKey];
}

void DouXLoginDiagnosticsRecord(NSString *event) {
    if (!DouXLoginDiagnosticsEnabled() || !event.length) return;
    // IMPORTANT: only fixed internal event identifiers may be recorded.
    // Never store usernames, raw URLs, query parameters, error descriptions,
    // cookies, OAuth codes, authorization headers or login tokens.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    @synchronized (defaults) {
        NSArray *previous = [defaults arrayForKey:kDouXLoginEventsKey] ?: @[];
        NSMutableArray *events = [previous mutableCopy];
        NSString *entry = [NSString stringWithFormat:@"%@ | %@", [NSDate date], event];
        [events addObject:entry];
        while (events.count > 150) [events removeObjectAtIndex:0];
        [defaults setObject:events forKey:kDouXLoginEventsKey];
    }
}

static NSString *DouXLoginURLClass(NSURL *URL) {
    NSString *scheme = URL.scheme.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"])
        return @"web";
    if (scheme.length) return @"custom-scheme";
    return @"unknown";
}

static NSString *DouXLoginReport(void) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = bundle.infoDictionary ?: @{};
    NSString *bundleID = bundle.bundleIdentifier ?: @"unknown";
    NSString *version = info[@"CFBundleShortVersionString"] ?: @"unknown";
    NSArray *types = info[@"CFBundleURLTypes"];
    NSUInteger schemeCount = 0;
    if ([types isKindOfClass:[NSArray class]]) {
        for (NSDictionary *item in types) {
            NSArray *schemes = item[@"CFBundleURLSchemes"];
            if ([schemes isKindOfClass:[NSArray class]])
                schemeCount += schemes.count;
        }
    }
    NSArray *events = [[NSUserDefaults standardUserDefaults] arrayForKey:kDouXLoginEventsKey] ?: @[];
    return [NSString stringWithFormat:
        @"DouX Login Diagnostics\n"
        @"TikTok bundle: %@\n"
        @"TikTok version: %@\n"
        @"Registered URL schemes: %lu\n"
        @"Login compatibility: %@\n"
        @"Login Safe Mode: %@\n"
        @"Events: %lu\n\n%@\n\n"
        @"Environment check:\n%@\n\n"
        @"Network self-check:\n%@\n\n"
        @"Timeline:\n%@\n\n"
        @"Only event categories are captured; no full URLs, passwords or tokens.",
         bundleID, version, (unsigned long)schemeCount,
         [[NSUserDefaults standardUserDefaults] boolForKey:@"login_compat_mode"] ? @"ON" : @"OFF",
         [[NSUserDefaults standardUserDefaults] boolForKey:@"login_isolation_mode"] ? @"ON" : @"OFF",
         (unsigned long)events.count,
         DouXLoginAssessment(events),
         DouXLoginEnvironmentReport(),
         DouXLoginSelfCheckResult(),
         [events componentsJoinedByString:@"\n"]];
}

void DouXLoginDiagnosticsShow(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ DouXLoginDiagnosticsShow(); });
        return;
    }
    UIWindow *window = nil;
    for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
        if (candidate.isKeyWindow) { window = candidate; break; }
    }
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *controller = window.rootViewController;
    for (NSUInteger i=0; controller && i < 12; i++) {
        if (controller.presentedViewController) {
            controller = controller.presentedViewController;
        } else if ([controller isKindOfClass:[UINavigationController class]]) {
            UIViewController *visible = ((UINavigationController *)controller).visibleViewController;
            if (!visible || visible == controller) break;
            controller = visible;
        } else if ([controller isKindOfClass:[UITabBarController class]]) {
            UIViewController *selected = ((UITabBarController *)controller).selectedViewController;
            if (!selected || selected == controller) break;
            controller = selected;
        } else break;
    }
    if (!controller || [controller isKindOfClass:[UIAlertController class]]) return;
    NSString *fullReport = DouXLoginReport();
    NSArray *events = [[NSUserDefaults standardUserDefaults] arrayForKey:kDouXLoginEventsKey] ?: @[];
    NSArray *recent = (events.count > 7)
        ? [events subarrayWithRange:NSMakeRange(events.count - 7, 7)] : events;
    NSString *preview = [NSString stringWithFormat:
        @"Login Safe Mode: %@ (restart after changing)\n\nAssessment:\n%@\n\nConnectivity:\n%@\n\nRecent events (%lu):\n%@\n\n"
        @"Run Full Check tests web access and signing metadata without signing in.",
        [[NSUserDefaults standardUserDefaults] boolForKey:@"login_isolation_mode"]
            ? @"ON" : @"OFF",
        DouXLoginAssessment(events),
        DouXLoginSelfCheckResult(),
        (unsigned long)events.count,
        recent.count ? [recent componentsJoinedByString:@"\n"] : @"No events yet"];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"DouX Login Diagnostics"
                        message:preview
                 preferredStyle:UIAlertControllerStyleAlert];
    BOOL safeMode = [[NSUserDefaults standardUserDefaults]
        boolForKey:@"login_isolation_mode"];
    [alert addAction:[UIAlertAction actionWithTitle:
        (safeMode ? @"Restore DouX Tweaks (restart)" : @"Enable Login Safe Mode (restart)")
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] setBool:!safeMode
                                               forKey:@"login_isolation_mode"];
        DouXLoginDiagnosticsRecord(safeMode ? @"safe_mode_disabled" :
                                             @"safe_mode_enabled");
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Run Full Check"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        DouXLoginRunFullCheck();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Copy Report"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = fullReport;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear Events"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDouXLoginEventsKey];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close"
        style:UIAlertActionStyleCancel handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

@interface DouXLoginObserver : NSObject
+ (void)start;
@end

@implementation DouXLoginObserver
+ (void)start {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kDouXLoginEnabledKey: @YES
    }];
    DouXLoginDiagnosticsRecord(@"diagnostics_started");
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(activated:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(backgrounded:)
                   name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(foregrounded:)
                   name:UIApplicationWillEnterForegroundNotification object:nil];
}
+ (void)activated:(NSNotification *)note {
    DouXLoginDiagnosticsRecord(@"app_active");
    DouXInstallCurrentCallbackProbes();
}
+ (void)backgrounded:(NSNotification *)note {
    DouXLoginDiagnosticsRecord(@"app_backgrounded");
}
+ (void)foregrounded:(NSNotification *)note {
    DouXLoginDiagnosticsRecord(@"app_foregrounded");
    DouXInstallCurrentCallbackProbes();
}
@end

// Instrument only the app delegate callback, while forwarding the unmodified
// arguments and original selector. No login token/callback URL is inspected.
static BOOL DouXOpenURLCallback(id self, SEL command, UIApplication *app,
                               NSURL *url, NSDictionary *options) {
    DouXLoginDiagnosticsRecord(
        [NSString stringWithFormat:@"app_callback_received_%@", DouXLoginURLClass(url)]);
    SEL original = NSSelectorFromString(@"doux_original_application:openURL:options:");
    Method backup = class_getInstanceMethod(object_getClass(self), original);
    if (!backup) return NO;
    BOOL (*originalIMP)(id, SEL, UIApplication *, NSURL *, NSDictionary *) =
        (BOOL (*)(id, SEL, UIApplication *, NSURL *, NSDictionary *))
        method_getImplementation(backup);
    return originalIMP(self, command, app, url, options);
}

static BOOL DouXContinueActivityCallback(id self, SEL command, UIApplication *app,
                                         NSUserActivity *activity, void (^restoration)(NSArray *)) {
    DouXLoginDiagnosticsRecord(@"app_universal_link_or_user_activity_received");
    SEL original = NSSelectorFromString(
        @"doux_original_application:continueUserActivity:restorationHandler:");
    Method backup = class_getInstanceMethod(object_getClass(self), original);
    if (!backup) return NO;
    BOOL (*originalIMP)(id, SEL, UIApplication *, NSUserActivity *, void (^)(NSArray *)) =
        (BOOL (*)(id, SEL, UIApplication *, NSUserActivity *, void (^)(NSArray *)))
        method_getImplementation(backup);
    return originalIMP(self, command, app, activity, restoration);
}

static void DouXInstallCallbackProbe(id delegate, SEL target, SEL alias, IMP wrapper) {
    if (!delegate) return;
    Class cls = object_getClass(delegate);
    Method method = class_getInstanceMethod(cls, target);
    if (!method) return;
    const char *types = method_getTypeEncoding(method);
    IMP existing = method_getImplementation(method);
    if (class_addMethod(cls, alias, existing, types)) {
        class_replaceMethod(cls, target, wrapper, types);
        DouXLoginDiagnosticsRecord(@"app_callback_probe_installed");
    }
}

static void DouXInstallDelegateProbes(id delegate) {
    DouXInstallCallbackProbe(delegate, @selector(application:openURL:options:),
        NSSelectorFromString(@"doux_original_application:openURL:options:"),
        (IMP)DouXOpenURLCallback);
    DouXInstallCallbackProbe(delegate,
        @selector(application:continueUserActivity:restorationHandler:),
        NSSelectorFromString(
            @"doux_original_application:continueUserActivity:restorationHandler:"),
        (IMP)DouXContinueActivityCallback);
}

// Scene-based iOS applications may receive OAuth callbacks on the active
// UISceneDelegate rather than the UIApplicationDelegate.
static void DouXSceneOpenURLCallback(id self, SEL command, UIScene *scene,
                                      NSSet *contexts) {
    DouXLoginDiagnosticsRecord(@"scene_url_callback_received");
    SEL original = NSSelectorFromString(@"doux_original_scene:openURLContexts:");
    Method backup = class_getInstanceMethod(object_getClass(self), original);
    if (!backup) return;
    void (*imp)(id, SEL, UIScene *, NSSet *) =
        (void (*)(id, SEL, UIScene *, NSSet *))method_getImplementation(backup);
    imp(self, command, scene, contexts);
}

static void DouXSceneActivityCallback(id self, SEL command, UIScene *scene,
                                       NSUserActivity *activity) {
    DouXLoginDiagnosticsRecord(@"scene_user_activity_received");
    SEL original = NSSelectorFromString(@"doux_original_scene:continueUserActivity:");
    Method backup = class_getInstanceMethod(object_getClass(self), original);
    if (!backup) return;
    void (*imp)(id, SEL, UIScene *, NSUserActivity *) =
        (void (*)(id, SEL, UIScene *, NSUserActivity *))
        method_getImplementation(backup);
    imp(self, command, scene, activity);
}

static void DouXInstallSceneProbes(id delegate) {
    DouXInstallCallbackProbe(delegate, @selector(scene:openURLContexts:),
        NSSelectorFromString(@"doux_original_scene:openURLContexts:"),
        (IMP)DouXSceneOpenURLCallback);
    DouXInstallCallbackProbe(delegate, @selector(scene:continueUserActivity:),
        NSSelectorFromString(@"doux_original_scene:continueUserActivity:"),
        (IMP)DouXSceneActivityCallback);
}

static void DouXInstallCurrentCallbackProbes(void) {
    UIApplication *app = [UIApplication sharedApplication];
    DouXInstallDelegateProbes(app.delegate);
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            DouXInstallSceneProbes(scene.delegate);
        }
    }
}

%hook UIApplication
- (void)setDelegate:(id<UIApplicationDelegate>)delegate {
    %orig(delegate);
    DouXInstallDelegateProbes(delegate);
}
- (void)openURL:(NSURL *)url options:(NSDictionary *)options
   completionHandler:(void (^)(BOOL))completion {
    DouXLoginDiagnosticsRecord(
        [NSString stringWithFormat:@"external_url_open_%@", DouXLoginURLClass(url)]);
    %orig(url, options, completion);
}
- (BOOL)openURL:(NSURL *)url {
    DouXLoginDiagnosticsRecord(
        [NSString stringWithFormat:@"external_legacy_url_open_%@", DouXLoginURLClass(url)]);
    return %orig(url);
}
%end

// Both can occur before Google / TikTok's browser authentication completes.
// This callback is delivered directly to the ASWebAuthenticationSession
// completion handler in many login flows, not to UIApplicationDelegate.
// Record only completion status; never read or persist the callback URL.
static BOOL DouXLoginCallbackHasParameter(NSURL *url, NSString *key) {
    if (!url || !key) return NO;
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url
                                       resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in parts.queryItems) {
        if ([item.name.lowercaseString isEqualToString:key]) return YES;
    }
    // OAuth providers sometimes use URL fragments instead of the query.
    // Only inspect parameter NAMES; never retain or log their values.
    NSString *fragment = parts.fragment ?: @"";
    for (NSString *part in [fragment componentsSeparatedByString:@"&"]) {
        NSRange equals = [part rangeOfString:@"="];
        NSString *name = (equals.location == NSNotFound) ? part :
            [part substringToIndex:equals.location];
        if ([name.lowercaseString isEqualToString:key]) return YES;
    }
    return NO;
}

static void DouXLoginRecordAuthResult(NSURL *callbackURL, NSError *error) {
    if (error) {
        // Error codes are not credentials; avoid persisting localized
        // descriptions or userInfo, which can embed sensitive URLs.
        NSString *kind = [error.domain hasPrefix:@"com.apple.AuthenticationServices"]
            ? @"apple_auth" : @"other";
        DouXLoginDiagnosticsRecord([NSString stringWithFormat:
            @"web_auth_completed_error_%@_%ld", kind, (long)error.code]);
    } else if (callbackURL) {
        DouXLoginDiagnosticsRecord(@"web_auth_completed_callback_received");
        if (DouXLoginCallbackHasParameter(callbackURL, @"error") ||
            DouXLoginCallbackHasParameter(callbackURL, @"error_code")) {
            DouXLoginDiagnosticsRecord(@"web_auth_completed_oauth_error");
        } else if (DouXLoginCallbackHasParameter(callbackURL, @"code") ||
                   DouXLoginCallbackHasParameter(callbackURL, @"auth_code")) {
            DouXLoginDiagnosticsRecord(@"web_auth_completed_authorization_code");
        } else {
            DouXLoginDiagnosticsRecord(@"web_auth_completed_callback_without_code_or_error");
        }
    } else {
        DouXLoginDiagnosticsRecord(@"web_auth_completed_without_callback");
    }
}

static BOOL DouXLoginCallbackSchemeRegistered(NSString *scheme) {
    if (!scheme.length) return NO;
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSArray *types = info[@"CFBundleURLTypes"];
    for (NSDictionary *item in types) {
        for (NSString *entry in item[@"CFBundleURLSchemes"]) {
            if ([entry caseInsensitiveCompare:scheme] == NSOrderedSame)
                return YES;
        }
    }
    return NO;
}

%hook ASWebAuthenticationSession
- (instancetype)initWithURL:(NSURL *)URL
          callbackURLScheme:(NSString *)callbackURLScheme
          completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    DouXLoginDiagnosticsRecord(@"web_auth_legacy_initializer");
    if (callbackURLScheme.length) {
        DouXLoginDiagnosticsRecord(
            DouXLoginCallbackSchemeRegistered(callbackURLScheme)
                ? @"web_auth_callback_scheme_registered"
                : @"web_auth_callback_scheme_not_registered");
    }
    if (!completionHandler) return %orig(URL, callbackURLScheme, completionHandler);
    void (^wrapped)(NSURL *, NSError *) = ^(NSURL *callbackURL, NSError *error) {
        DouXLoginRecordAuthResult(callbackURL, error);
        completionHandler(callbackURL, error);
    };
    return %orig(URL, callbackURLScheme, wrapped);
}

// Newer AuthenticationServices versions allow a callback matching object.
- (instancetype)initWithURL:(NSURL *)URL
                   callback:(id)callback
          completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    DouXLoginDiagnosticsRecord(@"web_auth_modern_initializer");
    if (!completionHandler) return %orig(URL, callback, completionHandler);
    void (^wrapped)(NSURL *, NSError *) = ^(NSURL *callbackURL, NSError *error) {
        DouXLoginRecordAuthResult(callbackURL, error);
        completionHandler(callbackURL, error);
    };
    return %orig(URL, callback, wrapped);
}

- (BOOL)start {
    DouXLoginDiagnosticsRecord(@"web_auth_session_started");
    BOOL didStart = %orig;
    DouXLoginDiagnosticsRecord(didStart ? @"web_auth_start_accepted" :
                                         @"web_auth_start_rejected");
    return didStart;
}
- (void)cancel {
    DouXLoginDiagnosticsRecord(@"web_auth_session_cancelled");
    %orig;
}
%end

%hook SFSafariViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    DouXLoginDiagnosticsRecord(@"in_app_safari_displayed");
}
%end

// Works on the sign-in screen, even when DouX Settings is unreachable:
// shake the phone after closing any error alert to open/copy diagnostics.
%hook UIWindow
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig(motion, event);
    if (motion == UIEventSubtypeMotionShake &&
        DouXLoginDiagnosticsEnabled())
        DouXLoginDiagnosticsShow();
}
%end

%ctor {
    [DouXLoginObserver start];
}
