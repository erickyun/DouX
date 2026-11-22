#import <Foundation/Foundation.h>
#import "DouXLoginDiagnostics.h"

// Read-only telemetry for a subset of public URLSession requests.
// Some TikTok builds use TTNet (not URLSession); absence of events is NOT
// evidence that requests were not made. Never read response bodies, headers,
// request bodies, cookies, URL query parameters or full URL paths.

static NSString *DouXLoginProvider(NSURL *url) {
    NSString *host = url.host.lowercaseString ?: @"";
    if ([host isEqualToString:@"tiktok.com"] || [host hasSuffix:@".tiktok.com"] ||
        [host isEqualToString:@"tiktokv.com"] || [host hasSuffix:@".tiktokv.com"] ||
        [host isEqualToString:@"musical.ly"] || [host hasSuffix:@".musical.ly"] ||
        [host isEqualToString:@"byteoversea.com"] || [host hasSuffix:@".byteoversea.com"])
        return @"tiktok";
    if ([host isEqualToString:@"accounts.google.com"] ||
        [host isEqualToString:@"oauth2.googleapis.com"])
        return @"google";
    return nil;
}

static BOOL DouXLoginIsAuthPath(NSURL *url) {
    NSString *path = url.path.lowercaseString ?: @"";
    for (NSString *term in @[@"login", @"passport", @"oauth", @"authorize",
                             @"account", @"verify", @"token", @"auth",
                             @"user/sign", @"session"]) {
        if ([path containsString:term]) return YES;
    }
    return NO;
}

static NSString *DouXLoginTransportErrorClass(NSError *error) {
    if (!error) return nil;
    if (![error.domain isEqualToString:NSURLErrorDomain]) return @"other";
    switch (error.code) {
        case NSURLErrorTimedOut: return @"timeout";
        case NSURLErrorCannotFindHost:
        case NSURLErrorDNSLookupFailed: return @"dns";
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorCannotConnectToHost: return @"connection";
        case NSURLErrorSecureConnectionFailed:
        case NSURLErrorServerCertificateHasBadDate:
        case NSURLErrorServerCertificateUntrusted:
        case NSURLErrorServerCertificateHasUnknownRoot:
        case NSURLErrorServerCertificateNotYetValid: return @"tls";
        case NSURLErrorCancelled: return @"cancelled";
        default: return @"other";
    }
}

static void DouXLoginRecordResponse(NSString *provider, BOOL isAuth,
                                     NSURLResponse *response, NSError *error) {
    NSString *err = DouXLoginTransportErrorClass(error);
    if (err) {
        if (![err isEqualToString:@"cancelled"])
            DouXLoginDiagnosticsRecord(
                [NSString stringWithFormat:@"network_%@_error_%@", provider, err]);
        return;
    }
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) return;
    NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
    // Never collect routine feed/media traffic. Only auth responses and
    // actionable HTTP errors from TikTok or Google's auth endpoints.
    if (isAuth || code == 401 || code == 403 || code == 429 || code >= 500) {
        NSString *bucket = code >= 200 && code < 300 ? @"2xx"
            : code >= 300 && code < 400 ? @"3xx"
            : code >= 400 && code < 500 ? @"4xx"
            : code >= 500 ? @"5xx" : @"other";
        NSString *status = (code == 401 || code == 403 || code == 429)
            ? [NSString stringWithFormat:@"%ld", (long)code] : bucket;
        DouXLoginDiagnosticsRecord(
            [NSString stringWithFormat:@"network_%@_%@_%@",
                provider, isAuth ? @"auth" : @"general", status]);
    }
}

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
     completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (!completionHandler) return %orig(request, completionHandler);
    NSString *provider = DouXLoginProvider(request.URL);
    if (!provider) return %orig(request, completionHandler);
    BOOL auth = DouXLoginIsAuthPath(request.URL);
    void (^wrapped)(NSData *, NSURLResponse *, NSError *) =
        ^(NSData *data, NSURLResponse *response, NSError *error) {
        DouXLoginRecordResponse(provider, auth, response, error);
        completionHandler(data, response, error);
    };
    return %orig(request, wrapped);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
     completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (!completionHandler) return %orig(url, completionHandler);
    NSString *provider = DouXLoginProvider(url);
    if (!provider) return %orig(url, completionHandler);
    BOOL auth = DouXLoginIsAuthPath(url);
    void (^wrapped)(NSData *, NSURLResponse *, NSError *) =
        ^(NSData *data, NSURLResponse *response, NSError *error) {
        DouXLoginRecordResponse(provider, auth, response, error);
        completionHandler(data, response, error);
    };
    return %orig(url, wrapped);
}
%end
