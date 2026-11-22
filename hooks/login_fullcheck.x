#import "DouXLoginDiagnostics.h"
#import <Security/Security.h>

static NSString * const kDouXSelfCheckResultKey = @"doux_login_full_check_v2";
static BOOL gDouXLoginCheckInProgress = NO;

// Diagnose signing/URL callback compatibility without accessing the keychain,
// reading cookies, or impersonating the original App Store app.
NSString *DouXLoginEnvironmentReport(void) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleID = bundle.bundleIdentifier ?: @"unknown";
    NSDictionary *info = bundle.infoDictionary ?: @{};
    NSArray *types = [info[@"CFBundleURLTypes"] isKindOfClass:[NSArray class]]
        ? info[@"CFBundleURLTypes"] : @[];
    NSMutableSet<NSString *> *schemes = [NSMutableSet set];
    NSUInteger entries = 0;
    for (NSDictionary *type in types) {
        if (![type isKindOfClass:[NSDictionary class]]) continue;
        NSArray *items = type[@"CFBundleURLSchemes"];
        if (![items isKindOfClass:[NSArray class]]) continue;
        for (id item in items) {
            if (![item isKindOfClass:[NSString class]]) continue;
            NSString *scheme = [item lowercaseString];
            if (scheme.length) {
                entries++;
                [schemes addObject:scheme];
            }
        }
    }

    // Entitlements are read from the signature of THIS app, never edited.
    NSString *appIdentifier = nil, *team = nil;
    NSArray *keychain = nil, *associated = nil;
    SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
    if (task) {
        CFTypeRef appValue = SecTaskCopyValueForEntitlement(
            task, CFSTR("application-identifier"), NULL);
        if (!appValue) appValue = SecTaskCopyValueForEntitlement(
            task, CFSTR("com.apple.application-identifier"), NULL);
        CFTypeRef teamValue = SecTaskCopyValueForEntitlement(
            task, CFSTR("com.apple.developer.team-identifier"), NULL);
        CFTypeRef keysValue = SecTaskCopyValueForEntitlement(
            task, CFSTR("keychain-access-groups"), NULL);
        CFTypeRef domainsValue = SecTaskCopyValueForEntitlement(
            task, CFSTR("com.apple.developer.associated-domains"), NULL);
        id a = CFBridgingRelease(appValue);
        id t = CFBridgingRelease(teamValue);
        id k = CFBridgingRelease(keysValue);
        id d = CFBridgingRelease(domainsValue);
        if ([a isKindOfClass:[NSString class]]) appIdentifier = a;
        if ([t isKindOfClass:[NSString class]]) team = t;
        if ([k isKindOfClass:[NSArray class]]) keychain = k;
        if ([d isKindOfClass:[NSArray class]]) associated = d;
        CFRelease(task);
    }
    BOOL match = appIdentifier &&
        [appIdentifier hasSuffix:[@"." stringByAppendingString:bundleID]];
    BOOL googleReverseScheme = NO;
    for (NSString *scheme in schemes) {
        if ([scheme hasPrefix:@"com.googleusercontent.apps."]) {
            googleReverseScheme = YES; break;
        }
    }
    NSString *appIDState = !appIdentifier ? @"unavailable"
        : (match ? @"matches_bundle" : @"does_not_match_bundle");
    return [NSString stringWithFormat:
        @"App bundle: %@\n"
         "App ID entitlement: %@\n"
         "Signing team: %@\n"
         "Keychain access groups: %@\n"
         "Associated domains: %@\n"
         "Registered callback schemes: %lu (%lu unique)\n"
         "Google reversed-client scheme present: %@\n"
         "Note: entitlement presence does not prove TikTok accepts this signature.",
         bundleID, appIDState, team.length ? @"present" : @"unavailable",
         keychain ? [NSString stringWithFormat:@"%lu", (unsigned long)keychain.count] : @"unavailable",
         associated ? [NSString stringWithFormat:@"%lu", (unsigned long)associated.count] : @"unavailable",
         (unsigned long)entries, (unsigned long)schemes.count,
         googleReverseScheme ? @"yes" : @"no/other flow"];
}

NSString *DouXLoginSelfCheckResult(void) {
    NSString *saved = [[NSUserDefaults standardUserDefaults]
        stringForKey:kDouXSelfCheckResultKey];
    return saved.length ? saved : @"Not run yet";
}

NSString *DouXLoginAssessment(NSArray<NSString *> *events) {
    // Prioritize actual transport and authorization outcomes over assumptions
    // based only on Safari foreground/background transitions.
    BOOL oauthCallback = NO, oauthError = NO, oauthCode = NO;
    BOOL blocked = NO, rateLimit = NO, transport = NO, started = NO;
    BOOL postAuthNetworkVisible = NO;
    for (NSString *event in events) {
        if ([event containsString:@"web_auth_session_started"]) started = YES;
        if ([event containsString:@"web_auth_completed_callback_received"] ||
            [event containsString:@"web_auth_completed_authorization_code"] ||
            [event containsString:@"web_auth_completed_oauth_error"])
            oauthCallback = YES;
        if ([event containsString:@"web_auth_completed_oauth_error"]) oauthError = YES;
        if ([event containsString:@"web_auth_completed_authorization_code"]) oauthCode = YES;
        if ([event containsString:@"network_tiktok_auth"] ||
            [event containsString:@"network_tiktok_general"])
            postAuthNetworkVisible = YES;
        if ([event containsString:@"_429"]) rateLimit = YES;
        if ([event containsString:@"_401"] || [event containsString:@"_403"]) blocked = YES;
        if ([event containsString:@"_error_dns"] || [event containsString:@"_error_tls"] ||
            [event containsString:@"_error_timeout"] ||
            [event containsString:@"_error_connection"]) transport = YES;
    }
    if (rateLimit)
        return @"A TikTok/Google HTTP 429 was observed. Rate limiting is possible. Avoid repeated login attempts; retry later using the official flow.";
    if (transport)
        return @"A DNS/TLS/connectivity error was observed. Check NextDNS/VPN/network filters first; do not assume this is an account problem.";
    if (oauthError)
        return @"The web-auth session returned an OAuth error parameter. Browser callback was received, but authorization was not confirmed.";
    if (blocked)
        return @"An HTTP 401/403 was observed on an auth-related or TikTok request. This may indicate rejection, but the endpoint's context is unknown.";
    if (oauthCode)
        return @"An OAuth authorization-code parameter reached DouX. If TikTok is still logged out, investigate post-callback login exchange, signing/capability compatibility or server-side checks.";
    if (oauthCallback)
        return @"A web authentication callback reached DouX. The session callback is working; TikTok's subsequent login acceptance remains unverified.";
    if (started)
        return @"A browser authentication session started, but no completion event was recorded in this report. A callback problem is possible, not proven.";
    if (postAuthNetworkVisible)
        return @"TikTok network responses were observed, but the available status does not establish why login failed.";
    return @"No conclusive login failure signal was captured. TikTok may use TTNet rather than URLSession. App signing, server restrictions and account rate limits remain possible.";
}

static NSString *DouXLoginCheckStatus(NSURLResponse *response, NSError *error) {
    if (error) {
        if ([error.domain isEqualToString:NSURLErrorDomain]) {
            switch (error.code) {
                case NSURLErrorCannotFindHost:
                case NSURLErrorDNSLookupFailed: return @"DNS failure";
                case NSURLErrorNotConnectedToInternet: return @"Offline";
                case NSURLErrorTimedOut: return @"Timeout";
                case NSURLErrorSecureConnectionFailed:
                case NSURLErrorServerCertificateUntrusted:
                    return @"TLS/certificate failure";
                default: return @"Connection error";
            }
        }
        return @"Connection error";
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        return [NSString stringWithFormat:@"HTTP %ld (server reached)", (long)code];
    }
    return @"Unexpected response";
}

void DouXLoginRunFullCheck(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ DouXLoginRunFullCheck(); });
        return;
    }
    if (gDouXLoginCheckInProgress) return;
    gDouXLoginCheckInProgress = YES;
    DouXLoginDiagnosticsRecord(@"full_check_started");

    // Explicit, two-host connectivity check; no account data is sent.
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 9.0;
    config.timeoutIntervalForResource = 12.0;
    config.URLCache = nil;
    config.HTTPCookieStorage = nil;
    config.HTTPShouldSetCookies = NO;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSDictionary<NSString *, NSString *> *hosts = @{
        @"TikTok web": @"https://www.tiktok.com/",
        @"Google accounts": @"https://accounts.google.com/"
    };
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary<NSString *, NSString *> *results = [NSMutableDictionary dictionary];
    for (NSString *name in hosts) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
            [NSURL URLWithString:hosts[name]]];
        request.HTTPMethod = @"HEAD";
        request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        dispatch_group_enter(group);
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
            completionHandler:^(__unused NSData *data, NSURLResponse *response, NSError *error) {
                @synchronized(results) {
                    results[name] = DouXLoginCheckStatus(response, error);
                }
                dispatch_group_leave(group);
            }];
        [task resume];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [session finishTasksAndInvalidate];
        NSString *result = [NSString stringWithFormat:
            @"TikTok web: %@\nGoogle accounts: %@\n"
            "A successful HEAD request only verifies basic web connectivity, not TikTok login APIs.",
            results[@"TikTok web"] ?: @"No result",
            results[@"Google accounts"] ?: @"No result"];
        [[NSUserDefaults standardUserDefaults] setObject:result
                                                  forKey:kDouXSelfCheckResultKey];
        gDouXLoginCheckInProgress = NO;
        DouXLoginDiagnosticsRecord(@"full_check_finished");
        DouXLoginDiagnosticsShow();
    });
}
