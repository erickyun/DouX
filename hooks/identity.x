// DouX optional identity-cleanup hooks.
// These hooks are UI-only: post data and comment text remain untouched.
// TikTok internal class names vary by version, so hooks fail open if a class/key is absent.
#import "TikTokHeaders.h"
#import <objc/runtime.h>
#import <math.h>

static char kDouXIdentityHiddenKey;

static UIView *DouXIdentityViewForKey(id object, NSString *key) {
    if (!object || !key) return nil;
    @try {
        id result = [object valueForKey:key];
        return [result isKindOfClass:[UIView class]] ? (UIView *)result : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

// Restore only views that DouX itself hid. Do not reveal UI hidden by TikTok.
static void DouXIdentitySetHidden(UIView *view, BOOL shouldHide) {
    if (!view) return;
    BOOL hiddenByDouX = [objc_getAssociatedObject(view, &kDouXIdentityHiddenKey) boolValue];
    if (shouldHide) {
        if (!view.hidden) {
            view.hidden = YES;
            objc_setAssociatedObject(view, &kDouXIdentityHiddenKey, @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (hiddenByDouX) {
        view.hidden = NO;
        objc_setAssociatedObject(view, &kDouXIdentityHiddenKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// TikTok's AWECommentPanelCell is a UITableView, not an individual row.
// Newer TikTok builds also wrap avatars inside image views rather than exposing
// a stable avatarView property on the outer comment container.
static BOOL DouXIdentityCommentAvatarCandidate(UIView *candidate, UIView *row) {
    if (![candidate isKindOfClass:[UIImageView class]] || !candidate.superview) return NO;
    CGRect rect = [candidate convertRect:candidate.bounds toView:row];
    CGFloat width = CGRectGetWidth(rect), height = CGRectGetHeight(rect);
    if (width < 18.0 || width > 82.0 || height < 18.0 || height > 82.0) return NO;
    if (fabs(width - height) > 12.0) return NO;
    // Only the small leading avatar in a comment row. Do not hide pictures,
    // stickers, reaction buttons or images attached to the comment body.
    if (CGRectGetMinX(rect) < -3.0 || CGRectGetMinX(rect) > 42.0) return NO;
    if (CGRectGetMinY(rect) < -3.0 || CGRectGetMinY(rect) > 65.0) return NO;
    return YES;
}

static void DouXIdentityScanCommentImages(UIView *view, UIView *row, NSUInteger depth) {
    if (!view || depth > 10) return;
    if (DouXIdentityCommentAvatarCandidate(view, row)) {
        DouXIdentitySetHidden(view, [DouXManager hideCommentAvatars]);
    }
    for (UIView *child in view.subviews) {
        DouXIdentityScanCommentImages(child, row, depth + 1);
    }
}

static void DouXIdentityApplyCommentRow(UIView *row) {
    if (!row) return;
    DouXIdentitySetHidden(DouXIdentityViewForKey(row, @"nameLabel"),
                           [DouXManager hideCommentUsernames]);
    DouXIdentitySetHidden(DouXIdentityViewForKey(row, @"avatarView"),
                           [DouXManager hideCommentAvatars]);
    DouXIdentitySetHidden(DouXIdentityViewForKey(row, @"avatarBorderView"),
                           [DouXManager hideCommentAvatars]);
    DouXIdentityScanCommentImages(row, row, 0);
}

static BOOL DouXIdentityWithinCommentUI(UIView *view) {
    UIView *parent = view;
    for (NSUInteger n = 0; parent && n < 20; n++, parent = parent.superview) {
        NSString *name = NSStringFromClass([parent class]);
        if ([name rangeOfString:@"Comment" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL DouXIdentityWithinFeedUI(UIView *view, BOOL *avatarNamed) {
    BOOL feed = NO, avatar = NO;
    UIView *parent = view;
    for (NSUInteger n = 0; parent && n < 22; n++, parent = parent.superview) {
        NSString *name = NSStringFromClass([parent class]);
        if ([name rangeOfString:@"Avatar" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"UserHead" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            avatar = YES;
        }
        if ([name rangeOfString:@"Feed" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"PlayInteraction" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Aweme" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            feed = YES;
        }
    }
    if (avatarNamed) *avatarNamed = avatar;
    return feed;
}

static void DouXIdentityApplyImageFallback(UIImageView *image) {
    BOOL hideComment = [DouXManager hideCommentAvatars];
    BOOL hideFeed = [DouXManager hideVideoAvatars];
    BOOL hiddenByUs = [objc_getAssociatedObject(image, &kDouXIdentityHiddenKey) boolValue];
    if (!hideComment && !hideFeed && !hiddenByUs) return;
    UIWindow *window = image.window;
    if (!window || !image.superview) return;

    CGRect rect = [image convertRect:image.bounds toView:window];
    CGFloat width = CGRectGetWidth(rect), height = CGRectGetHeight(rect);
    CGFloat screenWidth = CGRectGetWidth(window.bounds), screenHeight = CGRectGetHeight(window.bounds);
    if (width < 18.0 || width > 90.0 || fabs(width - height) > 12.0 ||
        screenWidth <= 0.0 || screenHeight <= 0.0) {
        if (hiddenByUs) DouXIdentitySetHidden(image, NO);
        return;
    }

    // Comment avatars remain on the leading edge of comment rows, even when
    // TikTok changes the private row subclass or image-view property.
    if (CGRectGetMinX(rect) >= 0.0 && CGRectGetMinX(rect) < screenWidth * 0.12 &&
        DouXIdentityWithinCommentUI(image)) {
        DouXIdentitySetHidden(image, hideComment);
        return;
    }

    BOOL avatarNamed = NO;
    BOOL inFeed = DouXIdentityWithinFeedUI(image, &avatarNamed);
    CGFloat radius = image.layer.cornerRadius;
    if (image.superview) radius = MAX(radius, image.superview.layer.cornerRadius);
    BOOL roundImage = radius >= MIN(width, height) * 0.28;
    if (inFeed && (avatarNamed || roundImage) &&
        CGRectGetMinX(rect) > screenWidth * 0.72 &&
        CGRectGetMidY(rect) > screenHeight * 0.15 &&
        CGRectGetMidY(rect) < screenHeight * 0.85) {
        DouXIdentitySetHidden(image, hideFeed);
        return;
    }
    if (hiddenByUs) DouXIdentitySetHidden(image, NO);
}

static void DouXIdentityApplyCommentCell(UIView *cell) {
    BOOL hideNames = [DouXManager hideCommentUsernames];
    BOOL hideAvatars = [DouXManager hideCommentAvatars];
    // TikTok AWECommentPanelBaseCell exposes nameLabel, avatarView and
    // avatarBorderView in known versions. KVC protects newer versions.
    DouXIdentitySetHidden(DouXIdentityViewForKey(cell, @"nameLabel"), hideNames);
    DouXIdentitySetHidden(DouXIdentityViewForKey(cell, @"avatarView"), hideAvatars);
    DouXIdentitySetHidden(DouXIdentityViewForKey(cell, @"avatarBorderView"), hideAvatars);
    if ([cell isKindOfClass:[UITableView class]]) {
        for (UITableViewCell *row in ((UITableView *)cell).visibleCells) {
            DouXIdentityApplyCommentRow(row);
        }
    } else {
        DouXIdentityApplyCommentRow(cell);
    }
}

static BOOL DouXIdentityClassNameContains(id object, NSString *term) {
    if (!object || !term) return NO;
    NSString *name = NSStringFromClass([object class]);
    return name && [name rangeOfString:term options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL DouXIdentityIsElement(id element, NSString *name) {
    Class cls = NSClassFromString(name);
    return element && cls && [element isKindOfClass:cls];
}

static id DouXIdentityElementForRow(UIView *row) {
    @try {
        return [row valueForKey:@"element"];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

%hook AWECommentPanelCell
- (void)layoutSubviews {
    %orig;
    DouXIdentityApplyCommentCell((UIView *)self);
}
- (void)configWithComment:(id)comment {
    %orig;
    DouXIdentityApplyCommentCell((UIView *)self);
}
%end

// The creator-name button exists in known TikTok builds. Hide only its
// visible UI rather than editing the author model or the caption.
%hook AWEPlayInteractionAuthorUserNameButton
- (void)layoutSubviews {
    %orig;
    DouXIdentitySetHidden((UIView *)self, [DouXManager hideVideoUsernames]);
}
%end

// TikTok represents several right-side icons as model-backed element rows.
// Hide only the specific avatar/music rows, keeping likes and comments intact.
%hook AWEBaseElementView
- (void)layoutSubviews {
    %orig;
    id element = DouXIdentityElementForRow((UIView *)self);
    BOOL avatarRow = DouXIdentityIsElement(element, @"AWEPlayInteractionUserAvatarElement")
        || DouXIdentityIsElement(element, @"AWEPlayInteractionAvatarElement")
        || DouXIdentityIsElement(element, @"TTKPlayInteractionUserAvatarElement")
        || DouXIdentityClassNameContains(element, @"Avatar")
        || DouXIdentityClassNameContains(self, @"Avatar");
    BOOL musicRow = DouXIdentityIsElement(element, @"AWEPlayInteractionMusicElement")
        || DouXIdentityIsElement(element, @"AWEPlayInteractionMusicCoverElement")
        || DouXIdentityIsElement(element, @"TTKPlayInteractionMusicElement");
    if (avatarRow) {
        DouXIdentitySetHidden((UIView *)self, [DouXManager hideVideoAvatars]);
    } else if (musicRow) {
        DouXIdentitySetHidden((UIView *)self, [DouXManager hideMusicDisc]);
    }
}
%end

// Fallback for older builds where the music disc is its own UIView.
%hook AWEPlayInteractionMusicView
- (void)layoutSubviews {
    %orig;
    DouXIdentitySetHidden((UIView *)self, [DouXManager hideMusicDisc]);
}
%end

// Fallback for image-backed avatars on newer TikTok versions. This is limited
// to image views that are located in a comment/feed context and at an avatar
// position; the rest of the TikTok UI is left unchanged.
%hook UIImageView
- (void)layoutSubviews {
    %orig;
    DouXIdentityApplyImageFallback((UIImageView *)self);
}
- (void)didMoveToWindow {
    %orig;
    DouXIdentityApplyImageFallback((UIImageView *)self);
}
%end
