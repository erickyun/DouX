#import "DouXManager.h"
#import "TikTokHeaders.h"
#import <os/log.h>
#import "VaultManager.h"

static os_log_t douxmanager_log;

@implementation DouXManager

+ (void)load {
    douxmanager_log = os_log_create("com.kunihir0.doux", "DouXManager");
    // Enabled by default only in the login-compatibility branch.
    // registerDefaults does not overwrite the user's saved choice.
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"login_compat_mode": @YES,
        @"login_isolation_mode": @YES
    }];
}

+ (BOOL)hideAds {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_ads"];
}
+ (BOOL)downloadButton {
    if ([self loginIsolationMode]) return NO;
     return [[NSUserDefaults standardUserDefaults] boolForKey:@"download_button"];
}
+ (BOOL)shareSheet {
    if ([self loginIsolationMode]) return NO;
     return [[NSUserDefaults standardUserDefaults] boolForKey:@"share_sheet"];
}
+ (BOOL)removeWatermark {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"remove_watermark"];
}
+ (BOOL)hideElementButton {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"remove_elements_button"];
}
+ (BOOL)uploadRegion {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"upload_region"];
}
+ (BOOL)autoPlay {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"auto_play"];
}
+ (BOOL)stopPlay {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"stop_play"];
}
+ (BOOL)progressBar {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"show_porgress_bar"];
}
+ (BOOL)transparentCommnet {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"transparent_commnet"];
}
+ (BOOL)showUsername {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"show_username"];
}
+ (BOOL)hideCommentUsernames {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_comment_usernames"];
}
+ (BOOL)hideCommentAvatars {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_comment_avatars"];
}
+ (BOOL)hideVideoUsernames {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_video_usernames"];
}
+ (BOOL)hideVideoAvatars {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_video_avatars"];
}
+ (BOOL)hideMusicDisc {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_music_disc"];
}
+ (BOOL)disablePullToRefresh {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"pull_to_refresh"];
}
+ (BOOL)disableUnsensitive {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"disable_unsensitive"];
}
+ (BOOL)disableWarnings {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"disable_warnings"];
}
+ (BOOL)disableLive {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"disable_live"];
}
+ (BOOL)skipRecommendations {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"skip_recommnedations"];
}
+ (BOOL)likeConfirmation {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"like_confirm"];
}
+ (BOOL)likeCommentConfirmation {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"like_comment_confirm"];
}
+ (BOOL)dislikeCommentConfirmation {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"dislike_comment_confirm"];
}
+ (BOOL)followConfirmation {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"follow_confirm"];
}
+ (BOOL)profileSave {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"save_profile"];
}
+ (BOOL)profileCopy {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"copy_profile_information"];
}
+ (BOOL)profileVideoCount {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"uploaded_videos"];
}
+ (BOOL)loginCompatibilityMode {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"login_compat_mode"];
}
+ (BOOL)loginIsolationMode {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"login_isolation_mode"];
}
+ (BOOL)alwaysOpenSafari {
    if ([self loginIsolationMode]) return NO;
    // Keep TikTok's in-app OAuth/2FA handoff intact while compatibility
    // mode is enabled. External browser redirects can lose return state.
    return ![self loginCompatibilityMode] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"openInBrowser"];
}
+ (BOOL)regionChangingEnabled {
    if ([self loginIsolationMode]) return NO;
    // Authentication should see the device's actual region, even if the
    // user previously selected a spoofed region for feed browsing.
    return ![self loginCompatibilityMode] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"en_region"];
}
+ (BOOL)speedEnabled {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"playback_en"];
}
+ (BOOL)liveActionEnabled {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"en_livefunc"];
}
+ (NSNumber *)selectedLiveAction {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"live_action"];
}
+ (NSNumber *)selectedSpeed {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"playback_speed"];
}
+ (BOOL)videoLikeCount {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"video_like_count"];
}
+ (BOOL)videoUploadDate {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"video_upload_date"];
}
+ (NSDictionary *)selectedRegion {
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"region"];
}
+ (BOOL)fakeChangesEnabled {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"en_fake"];
}
+ (BOOL)fakeVerified {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"fake_verify"];
}
+ (BOOL)extendedBio {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"extended_bio"];
}
+ (BOOL)extendedComment {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"extendedComment"];
}
+ (BOOL)uploadHD {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"upload_hd"];
}
+ (BOOL)appLock {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"padlock"];
}
+ (BOOL)flexEnabled {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"flex_enabled"];
}

+ (BOOL)showVaultButton {
    if ([self loginIsolationMode]) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"show_vault_button"];
}
+ (void)cleanCache {
    NSArray <NSURL *> *DocumentFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *file in DocumentFiles) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"png"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"jpeg"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"mp3"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"m4a"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
    }
    
    NSArray <NSURL *> *TempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *file in TempFiles) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"mov"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"tmp"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"png"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"jpeg"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"mp3"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"m4a"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file hasDirectoryPath]) {
            if ([DouXManager isEmpty:file]) {
                [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
            }
        }
    }
}
+ (BOOL)isEmpty:(NSURL *)url {
    NSArray *FolderFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    if (FolderFiles.count == 0) {
        return true;
    } else {
        return false;
    }
}
+ (void)showSaveVC:(NSArray<NSURL *> *)item {
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:item applicationActivities:nil];
    if (is_iPad()) {
        acVC.popoverPresentationController.sourceView = topMostController().view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [topMostController() presentViewController:acVC animated:true completion:nil];
}

+ (void)saveMedia:(NSURL *)newFilePath withCreator:(NSString *)creator andType:(VaultMediaItemType)type {
    os_log_info(douxmanager_log, "DouXManager saveMedia called with path: %{public}@, creator: %{public}@", newFilePath.path, creator);

    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *vaultDirectory = [documentsDirectory stringByAppendingPathComponent:@"Vault"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:vaultDirectory]) {
        [fileManager createDirectoryAtPath:vaultDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSString *uniqueFileName = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], [newFilePath pathExtension]];
    NSString *newPath = [vaultDirectory stringByAppendingPathComponent:uniqueFileName];
    NSURL *newURL = [NSURL fileURLWithPath:newPath];

    [fileManager moveItemAtURL:newFilePath toURL:newURL error:nil];

    VaultMediaItem *item = [[VaultMediaItem alloc] init];
    item.internalID = [[NSUUID UUID] UUIDString];
    item.filePath = newPath;
    item.creatorUsername = creator;
    item.contentType = type;
    item.savedDate = [NSDate date];
    item.isFavorite = NO;

    [[VaultManager sharedManager] addVaultItem:item];
}

+ (void)saveMedia:(NSURL *)newFilePath {
    os_log_error(douxmanager_log, "Deprecated saveMedia: called. Please update to saveMedia:withCreator:andType:");
}

+ (NSString *)getDownloadingPersent:(float)per {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterPercentStyle];
    NSNumber *number = [NSNumber numberWithFloat:per];
    return [numberFormatter stringFromNumber:number];
}
@end