#import <Cordova/CDVViewController.h>
#import <objc/message.h>
#import <objc/runtime.h>

static char CDVOrientationSupportedOrientationsKey;

/*
 * Categories cannot add instance variables, so store the current orientation
 * list as an associated object on the CDVViewController instance.
 *
 * Supported orientations are represented as an NSArray of UIInterfaceOrientation
 * NSNumber values. Cordova iOS versions before 8 exposed compatible
 * supportedOrientations accessors directly on CDVViewController; Cordova iOS 8
 * removed them, so we provide them here instead of depending on the external
 * cordova-plugin-screen-orientation.
 */
static NSArray* CDVOrientationSupportedOrientations(id self, SEL _cmd)
{
    return objc_getAssociatedObject(self, &CDVOrientationSupportedOrientationsKey);
}

static void CDVOrientationSetSupportedOrientations(id self, SEL _cmd, NSArray* supportedOrientations)
{
    objc_setAssociatedObject(self,
                             &CDVOrientationSupportedOrientationsKey,
                             supportedOrientations,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/*
 * Safe only because these implementations are installed on CDVViewController and
 * nowhere else: the superclass is then UIViewController, whose own
 * implementation is the one that should run. Installing them on UIViewController
 * as well would make this call find this very function and recurse.
 */
static UIInterfaceOrientationMask CDVOrientationCallSuperSupportedInterfaceOrientations(id self, SEL _cmd)
{
    struct objc_super superInfo = {
        .receiver = self,
        .super_class = class_getSuperclass([CDVViewController class])
    };

    return ((UIInterfaceOrientationMask (*)(struct objc_super*, SEL))objc_msgSendSuper)(&superInfo, _cmd);
}

static UIInterfaceOrientationMask CDVOrientationSupportedInterfaceOrientations(id self, SEL _cmd)
{
    NSArray* supportedOrientations = CDVOrientationSupportedOrientations(self, @selector(supportedOrientations));

    /*
     * If the plugin has not set a dynamic orientation lock, preserve UIKit's
     * default behavior. The app's Info.plist still limits the orientations iOS
     * will actually allow.
     */
    if (supportedOrientations.count == 0) {
        return CDVOrientationCallSuperSupportedInterfaceOrientations(self, _cmd);
    }

    UIInterfaceOrientationMask supportedInterfaceOrientations = 0;

    /*
     * UIInterfaceOrientationMask values are bit masks derived from
     * UIInterfaceOrientation values, e.g. UIInterfaceOrientationMaskPortrait
     * is 1 << UIInterfaceOrientationPortrait.
     */
    for (NSNumber* orientation in supportedOrientations) {
        supportedInterfaceOrientations = supportedInterfaceOrientations | (1 << orientation.integerValue);
    }

    if (supportedInterfaceOrientations == 0) {
        return CDVOrientationCallSuperSupportedInterfaceOrientations(self, _cmd);
    }

    return supportedInterfaceOrientations;
}

static BOOL CDVOrientationShouldAutorotate(id self, SEL _cmd)
{
    NSArray* supportedOrientations = CDVOrientationSupportedOrientations(self, @selector(supportedOrientations));

    /*
     * If no dynamic orientation lock is set, allow autorotation
     */
    if (supportedOrientations == nil || supportedOrientations.count == 0) {
        return YES;
    }

    /*
     * If only one orientation is locked, disable autorotation to enforce the lock.
     *
     * This only has an effect up to iOS 15: UIKit deprecated shouldAutorotate in
     * iOS 16 and no longer consults it, so from iOS 16 on the lock rests entirely
     * on supportedInterfaceOrientations above.
     */
    return supportedOrientations.count > 1;
}

@interface CDVViewController (OSAppFeedbackOrientation)
@end

@implementation CDVViewController (OSAppFeedbackOrientation)

+ (void)load
{
    /*
     * Cordova iOS 8 removed CDVViewController's supportedOrientations API, but
     * this plugin still uses setSupportedOrientations: to change the view
     * controller's allowed orientations at runtime.
     *
     * Add the removed accessors back to CDVViewController, along with
     * supportedInterfaceOrientations, the method UIKit queries to determine the
     * orientations a view controller currently allows, and shouldAutorotate,
     * which UIKit only consults before iOS 16.
     *
     * These are deliberately installed on CDVViewController only. UIViewController
     * already implements supportedInterfaceOrientations and shouldAutorotate, so
     * adding them there is a silent no-op (class_addMethod returns NO and leaves
     * the existing method untouched) that would recurse if it ever stopped being
     * one. Leaving UIViewController alone also keeps the respondsToSelector:
     * checks in OSAppFeedback meaningful: a view controller that is not a
     * CDVViewController answers NO and the plugin logs that it cannot lock the
     * orientation, instead of silently doing nothing.
     */

    Class cdvViewControllerClass = [CDVViewController class];
    class_addMethod(cdvViewControllerClass,
                    NSSelectorFromString(@"supportedOrientations"),
                    (IMP)CDVOrientationSupportedOrientations,
                    "@@:");

    class_addMethod(cdvViewControllerClass,
                    NSSelectorFromString(@"setSupportedOrientations:"),
                    (IMP)CDVOrientationSetSupportedOrientations,
                    "v@:@");

    class_addMethod(cdvViewControllerClass,
                    @selector(supportedInterfaceOrientations),
                    (IMP)CDVOrientationSupportedInterfaceOrientations,
                    "Q@:");

    class_addMethod(cdvViewControllerClass,
                    @selector(shouldAutorotate),
                    (IMP)CDVOrientationShouldAutorotate,
                    "B@:");
}

@end
