// DouX optional identity-cleanup hooks.
// These hooks are UI-only: post data and comment text remain untouched.
// TikTok internal class names vary by version, so hooks fail open if a class/key is absent.
#import "TikTokHeaders.h"
#import <objc/runtime.h>
#import <math.h>
#import <objc/message.h>

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
    CGFloat left = CGRectGetMinX(rect), top = CGRectGetMinY(rect);
    if (left < -3.0 || left > 110.0 || top < -3.0 ||
        top > MAX(70.0, CGRectGetHeight(row.bounds))) return NO;
    if (left > 42.0) {
        // Replies are indented. Their smaller round avatars must not be
        // confused with square stickers or photo replies in the comment body.
        CGFloat radius = MAX(candidate.layer.cornerRadius,
                             candidate.superview.layer.cornerRadius);
        NSString *className = NSStringFromClass([candidate class]);
        NSString *parentClass = NSStringFromClass([candidate.superview class]);
        BOOL avatarClass = [className rangeOfString:@"Avatar"
                                                  options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [parentClass rangeOfString:@"Avatar"
                                      options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (!avatarClass && radius < MIN(width, height) * 0.27) return NO;
    }
    return YES;
}

// A reply is indented further than a top-level comment. Find its muted
// username label next to the avatar, without hiding its darker comment text.
static BOOL DouXIdentityLooksLikeUsernameLabel(UILabel *label) {
    if (!label || !label.text.length || label.text.length > 100 ||
        label.numberOfLines > 1 || label.font.pointSize < 10.0 ||
        label.font.pointSize > 18.0) return NO;
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    UIColor *color = [label.textColor resolvedColorWithTraitCollection:label.traitCollection];
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) return NO;
    CGFloat brightest = MAX(red, MAX(green, blue));
    CGFloat darkest = MIN(red, MIN(green, blue));
    return brightest - darkest < 0.20 && brightest >= 0.35 && brightest <= 0.87;
}

static BOOL DouXIdentityMaskNameNearAvatar(UIView *view, UIWindow *window,
                                           CGRect avatar, NSUInteger depth) {
    if (!view || depth > 7) return NO;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        CGRect frame = [label convertRect:label.bounds toView:window];
        BOOL nextToAvatar = CGRectGetMinX(frame) >= CGRectGetMaxX(avatar) + 2.0 &&
            CGRectGetMinX(frame) < CGRectGetMaxX(avatar) + 42.0 &&
            fabs(CGRectGetMidY(frame) - CGRectGetMidY(avatar)) < 23.0;
        if (nextToAvatar && DouXIdentityLooksLikeUsernameLabel(label)) {
            DouXIdentitySetHidden(label, [DouXManager hideCommentUsernames]);
            return YES;
        }
    }
    for (UIView *child in view.subviews) {
        if (DouXIdentityMaskNameNearAvatar(child, window, avatar, depth + 1)) return YES;
    }
    return NO;
}

static void DouXIdentityMaskNearbyCommentName(UIImageView *avatarView) {
    if (!avatarView.window || !avatarView.superview) return;
    CGRect avatar = [avatarView convertRect:avatarView.bounds toView:avatarView.window];
    UIView *parent = avatarView.superview;
    // Search the closest comment sub-tree first. Do not look outside the
    // containing comment table or collection and risk changing unrelated UI.
    for (NSUInteger i = 0; parent && i < 9; i++, parent = parent.superview) {
        if ([parent isKindOfClass:[UITableView class]] ||
            [parent isKindOfClass:[UICollectionView class]]) break;
        if (DouXIdentityMaskNameNearAvatar(parent, avatarView.window, avatar, 0)) break;
    }
}

static void DouXIdentityScanCommentImages(UIView *view, UIView *row, NSUInteger depth) {
    if (!view || depth > 10) return;
    if (DouXIdentityCommentAvatarCandidate(view, row)) {
        DouXIdentitySetHidden(view, [DouXManager hideCommentAvatars]);
        DouXIdentityMaskNearbyCommentName((UIImageView *)view);
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
    BOOL hideNames = [DouXManager hideCommentUsernames];
    BOOL hiddenByUs = [objc_getAssociatedObject(image, &kDouXIdentityHiddenKey) boolValue];
    if (!hideComment && !hideFeed && !hideNames && !hiddenByUs) return;
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
    if (CGRectGetMinX(rect) >= 0.0 && CGRectGetMinX(rect) < screenWidth * 0.26 &&
        DouXIdentityWithinCommentUI(image)) {
        DouXIdentitySetHidden(image, hideComment);
        DouXIdentityMaskNearbyCommentName(image);
        return;
    }

    BOOL avatarNamed = NO;
    BOOL inFeed = DouXIdentityWithinFeedUI(image, &avatarNamed);
    CGFloat radius = 0.0;
    BOOL hasCircularMask = NO;
    UIView *roundAncestor = image;
    for (NSUInteger depth = 0; roundAncestor && depth < 4; depth++,
         roundAncestor = roundAncestor.superview) {
        radius = MAX(radius, roundAncestor.layer.cornerRadius);
        if (roundAncestor.layer.mask &&
            fabs(CGRectGetWidth(roundAncestor.bounds) -
                 CGRectGetHeight(roundAncestor.bounds)) < 12.0) {
            hasCircularMask = YES;
        }
    }
    BOOL roundImage = radius >= MIN(width, height) * 0.27 || hasCircularMask;
    BOOL inRightAvatarSpot = CGRectGetMinX(rect) > screenWidth * 0.78 &&
        CGRectGetMidY(rect) > screenHeight * 0.37 &&
        CGRectGetMidY(rect) < screenHeight * 0.60 &&
        width >= 24.0 && width <= 70.0;
    if ((inFeed || inRightAvatarSpot) && (avatarNamed || roundImage) &&
        CGRectGetMinX(rect) > screenWidth * 0.72 &&
        CGRectGetMidY(rect) > screenHeight * 0.15 &&
        CGRectGetMidY(rect) < screenHeight * 0.85) {
        DouXIdentitySetHidden(image, hideFeed);
        return;
    }
    if (hiddenByUs) DouXIdentitySetHidden(image, NO);
}

// Also called from BDImageView's own layout hook, because subclass overrides
// can bypass UIKit's inherited UIImageView method implementation.
void DouXIdentityProcessImage(UIImageView *image) {
    DouXIdentityApplyImageFallback(image);
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

// Use the right-hand feed rail geometry only for the avatar-specific views.
// This avoids touching profile pages, comment stickers and the like/share rail.
static BOOL DouXIdentityIsRightFeedAvatar(UIView *view) {
    if (!view || !view.window || !view.superview) return NO;
    UIWindow *window = view.window;
    CGRect bounds = [view convertRect:view.bounds toView:window];
    CGFloat w = CGRectGetWidth(window.bounds), h = CGRectGetHeight(window.bounds);
    CGFloat diameter = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (w <= 0.0 || h <= 0.0) return NO;
    return diameter >= 24.0 && diameter <= 90.0 &&
        fabs(CGRectGetWidth(bounds) - CGRectGetHeight(bounds)) <= 18.0 &&
        CGRectGetMinX(bounds) > w * 0.71 &&
        CGRectGetMidY(bounds) > h * 0.30 &&
        CGRectGetMidY(bounds) < h * 0.67;
}

static void DouXIdentityUpdateFeedAvatarView(UIView *view) {
    if (DouXIdentityIsRightFeedAvatar(view) ||
        [objc_getAssociatedObject(view, &kDouXIdentityHiddenKey) boolValue]) {
        DouXIdentitySetHidden(view, [DouXManager hideVideoAvatars]);
    }
}

// TikTok's native right-rail avatar view. Unlike the follow-badge element,
// these views still display the profile picture after setHide: hides the badge.
%hook AWEAdAvatarView
- (void)layoutSubviews {
    %orig;
    DouXIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    DouXIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if ([DouXManager hideVideoAvatars] && DouXIdentityIsRightFeedAvatar((UIView *)self))
        hidden = YES;
    %orig(hidden);
}
%end

// On newer TikTok feeds the profile photo is hosted in a dedicated
// AWEPlayInteractionUserAvatarView, separate from its follow-prompt/plus view.
// Only mask it when located at the video author's right-rail avatar position.
%hook AWEPlayInteractionUserAvatarView
- (void)layoutSubviews {
    %orig;
    DouXIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    DouXIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if ([DouXManager hideVideoAvatars] && DouXIdentityIsRightFeedAvatar((UIView *)self))
        hidden = YES;
    %orig(hidden);
}
%end

%hook AWEPlayInteractionAvatarView
- (void)layoutSubviews {
    %orig;
    DouXIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    DouXIdentityUpdateFeedAvatarView((UIView *)self);
}
- (void)setHidden:(BOOL)hidden {
    if ([DouXManager hideVideoAvatars] && DouXIdentityIsRightFeedAvatar((UIView *)self))
        hidden = YES;
    %orig(hidden);
}
%end

// Some recent TikTok versions render the creator avatar and follow badge in
// a dedicated container rather than through AWEBaseElementView.
%hook AWEPlayInteractionUserProfileContainerView
- (void)layoutSubviews {
    %orig;
    DouXIdentitySetHidden((UIView *)self, [DouXManager hideVideoAvatars]);
}
- (void)setHidden:(BOOL)hidden {
    if ([DouXManager hideVideoAvatars]) hidden = YES;
    %orig(hidden);
}
%end

// The optimized feed avatar element is separate from the regular one.
%hook AWEPlayInteractionUserAvatarOptElementElement
- (void)layoutElementView {
    %orig;
    if ([DouXManager hideVideoAvatars] && [(id)self respondsToSelector:@selector(setHide:)]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(setHide:), YES);
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
