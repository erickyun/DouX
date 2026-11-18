// DouX optional identity-cleanup hooks.
// These hooks are UI-only: post data and comment text remain untouched.
// TikTok internal class names vary by version, so hooks fail open if a class/key is absent.
#import "TikTokHeaders.h"
#import <objc/runtime.h>

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

static void DouXIdentityApplyCommentCell(UIView *cell) {
    BOOL hideNames = [DouXManager hideCommentUsernames];
    BOOL hideAvatars = [DouXManager hideCommentAvatars];
    // TikTok AWECommentPanelBaseCell exposes nameLabel, avatarView and
    // avatarBorderView in known versions. KVC protects newer versions.
    DouXIdentitySetHidden(DouXIdentityViewForKey(cell, @"nameLabel"), hideNames);
    DouXIdentitySetHidden(DouXIdentityViewForKey(cell, @"avatarView"), hideAvatars);
    DouXIdentitySetHidden(DouXIdentityViewForKey(cell, @"avatarBorderView"), hideAvatars);
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
        || DouXIdentityIsElement(element, @"TTKPlayInteractionUserAvatarElement");
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
