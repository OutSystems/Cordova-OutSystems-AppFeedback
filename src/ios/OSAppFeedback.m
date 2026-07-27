//
//  OSAppFeedback.m
//  OutSystems
//
//
//

#import "OSAppFeedback.h"
#import "CDVReachability.h"
#import "CDVViewController+OSAppFeedbackOrientation.h"

NSString* const kAppFeedbackDefaultHostname = @"DefaultHostname";
NSString* const kAppFeedbackDefaultHandler = @"DefaultAppFeedbackHandler";

@interface OSAppFeedback()

@property (strong, nonatomic) UIView *mobileECTView;
@property (strong, nonatomic) NSString *hostname;
@property (nonatomic) BOOL inBackground;
@property (nonatomic) BOOL hasSettings;
@property (nonatomic) BOOL isECTAvailable;
@property (nonatomic) BOOL defaultHandler;
@property (strong, nonatomic) NSArray *originalSupportedOrientations;

/*
 * originalSupportedOrientations is nil whenever the app has not set an explicit
 * orientation lock, which is a legitimate value to save and restore. A separate
 * flag is therefore needed to tell "nothing saved yet" from "saved nil", so a
 * second lock cannot overwrite the saved value with an already-locked one.
 */
@property (nonatomic) BOOL didSaveOriginalSupportedOrientations;

@end

@implementation OSAppFeedback



-(void)pluginInitialize{
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPause) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResume) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    self.hasSettings = NO;
    self.isECTAvailable = NO;
    
    _mobileECTView = [[UIView alloc] init];
    
    [self.mobileECTView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.mobileECTView setBackgroundColor:[UIColor clearColor]];
    
    [self.viewController.view addSubview:_mobileECTView];
    
    [self.viewController.view addConstraint:[NSLayoutConstraint constraintWithItem:self.viewController.view
                                                                         attribute:NSLayoutAttributeCenterX
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_mobileECTView
                                                                         attribute:NSLayoutAttributeCenterX
                                                                        multiplier:1
                                                                          constant:0.0]];
    
    [self.viewController.view addConstraint:[NSLayoutConstraint constraintWithItem:self.viewController.view
                                                                         attribute:NSLayoutAttributeCenterY
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_mobileECTView
                                                                         attribute:NSLayoutAttributeCenterY
                                                                        multiplier:1
                                                                          constant:0.0]];
    
    [self.viewController.view addConstraint:[NSLayoutConstraint constraintWithItem:self.viewController.view
                                                                         attribute:NSLayoutAttributeHeight
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_mobileECTView
                                                                         attribute:NSLayoutAttributeHeight
                                                                        multiplier:1
                                                                          constant:0.0]];
    
    [self.viewController.view addConstraint:[NSLayoutConstraint constraintWithItem:self.viewController.view
                                                                         attribute:NSLayoutAttributeWidth
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_mobileECTView
                                                                         attribute:NSLayoutAttributeWidth
                                                                        multiplier:1
                                                                          constant:0.0]];
    
    [self.viewController.view addConstraint:[NSLayoutConstraint constraintWithItem:self.viewController.view
                                                                         attribute:NSLayoutAttributeHeight
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:_mobileECTView
                                                                         attribute:NSLayoutAttributeHeight
                                                                        multiplier:1
                                                                          constant:0.0]];
    
    [_mobileECTView setHidden:YES];
    
    self.hostname = [[self.commandDelegate settings] objectForKey:[kAppFeedbackDefaultHostname lowercaseString]];
    
    id defaultHandlerSetting = [[self.commandDelegate settings] objectForKey:[kAppFeedbackDefaultHandler lowercaseString]];
    
    if(!defaultHandlerSetting){
        self.defaultHandler = YES;
    }
    else{
        self.defaultHandler = [[[self.commandDelegate settings] objectForKey:kAppFeedbackDefaultHandler] boolValue];
    }
    
    if(self.defaultHandler){
        [self registerGestureHandler];
    }
    
}

-(void) onPause {
    self.inBackground = YES;
}

-(void) onResume {
    self.inBackground = NO;
}


- (AppDelegate *)appDelegate {
    return (AppDelegate*)[[UIApplication sharedApplication] delegate];
}


- (void)deviceready:(CDVInvokedUrlCommand*)command{
    
    if([[command arguments] count] > 0){
        _hostname = [[command arguments] objectAtIndex:0];
    }
    
    [self handleDeviceReady:_hostname];
}

- (void)isAvailable:(CDVInvokedUrlCommand*)command{
    
    if(self.inBackground) {
        return;
    }
    
    self.hasSettings = YES;
    
    [self handleIsECTAvailable:command];
   
}

- (void)openECT:(CDVInvokedUrlCommand*)command{
    
    if(self.inBackground) {
        return;
    }
    
    if(self.hasSettings && self.isECTAvailable) {
        [self.commandDelegate runInBackground:^{
            [self handleOpenECT:command];
        }];
    } else {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                 messageAsString:@"App Feedback is not available."]
                                    callbackId:[command callbackId]];
    }
    
}


-(void)lockToCurrentOrientation {

    CDVViewController* vc = (CDVViewController *) self.viewController;

    // Check if the view controller responds to the methods we need
    if (![vc respondsToSelector:@selector(supportedOrientations)] ||
        ![vc respondsToSelector:@selector(setSupportedOrientations:)]) {
        // View controller doesn't support dynamic orientation changes
        NSLog(@"[AppFeedback] View controller does not support dynamic orientation locking");
        return;
    }

    // Opening App Feedback twice without closing it in between must not save the
    // orientation locked by the first open as the one to restore.
    if(self.didSaveOriginalSupportedOrientations) {
        NSLog(@"[AppFeedback] Orientation is already locked");
        return;
    }

    UIWindow *window = vc.view.window;

    /*
     * Lock to the orientation the interface is actually in, rather than deriving
     * it from the physical device orientation. UIDevice reports FaceUp/FaceDown
     * when the device lies flat and Unknown before orientation notifications
     * start, and its landscape values are the reverse of the interface ones
     * (UIOrientation.h declares UIInterfaceOrientationLandscapeLeft ==
     * UIDeviceOrientationLandscapeRight), so translating between the two by name
     * locks to the opposite landscape and rotates the UI by 180 degrees.
     */
    UIInterfaceOrientation currentOrientation = window.windowScene.interfaceOrientation;

    if(currentOrientation == UIInterfaceOrientationUnknown) {
        NSLog(@"[AppFeedback] Current interface orientation is unknown, not locking orientation");
        return;
    }

    /*
     * Locking to an orientation the app itself does not support would leave UIKit
     * with an empty set of allowed orientations, which it reports as an
     * UIApplicationInvalidInterfaceOrientationException.
     */
    UIInterfaceOrientationMask appSupportedOrientations =
        [[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:window];

    if((appSupportedOrientations & (1 << currentOrientation)) == 0) {
        NSLog(@"[AppFeedback] Current interface orientation is not supported by the app, not locking orientation");
        return;
    }

    // Save the original orientations so they can be restored on close
    self.originalSupportedOrientations = [vc supportedOrientations];
    self.didSaveOriginalSupportedOrientations = YES;

    NSArray *orientationsToLock = @[@(currentOrientation)];

    [vc setSupportedOrientations:orientationsToLock];

    // Force iOS to re-evaluate supported orientations
    if (@available(iOS 16.0, *)) {
        [vc setNeedsUpdateOfSupportedInterfaceOrientations];
    } else {
        [UIViewController attemptRotationToDeviceOrientation];
    }

}

-(void)unlockOrientation {
    CDVViewController* vc = (CDVViewController *) self.viewController;

    // Check if the view controller responds to the method we need
    if (![vc respondsToSelector:@selector(setSupportedOrientations:)]) {
        NSLog(@"[AppFeedback] View controller does not support dynamic orientation unlocking");
        return;
    }

    if(!self.didSaveOriginalSupportedOrientations) {
        // Nothing was locked, so there is nothing to restore
        return;
    }

    /*
     * Restore whatever was saved, including nil: a nil or empty list makes
     * supportedInterfaceOrientations call the super implementation, which returns
     * the app's own orientations from its Info.plist.
     */
    [vc setSupportedOrientations:self.originalSupportedOrientations];

    self.originalSupportedOrientations = nil;
    self.didSaveOriginalSupportedOrientations = NO;

    // Force update the interface orientation
    if (@available(iOS 16.0, *)) {
        [vc setNeedsUpdateOfSupportedInterfaceOrientations];
    } else {
        // For iOS 15 and below, trigger a rotation update
        [UIViewController attemptRotationToDeviceOrientation];
    }

}

-(void)handleDeviceReady:(NSString*)hostname{
    if(!self.hostname || self.hostname.length == 0){
        self.hostname = hostname;
    }

    [self initEctController:self.hostname];
    
    [self.mobileECTController prepareECTData:^(BOOL result) {
        // do nothing
    }];
}

typedef void(^OSECTAvailabilityBlock)(BOOL);

-(void)checkECTAvailability:(OSECTAvailabilityBlock)completionBlock{
    
    [self.mobileECTController checkECTAvailability:^(BOOL result){
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.mobileECTController prepareForViewWillAppear];
        });
        
        self.isECTAvailable = result;
        
        if(completionBlock)
            completionBlock(result);
    }];
    
}


-(void)handleIsECTAvailable: (CDVInvokedUrlCommand*) command{
    
    if(!self.mobileECTController){
        CDVPluginResult* cdvResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unable to load App Feedback's native component."] ;
        [self.commandDelegate sendPluginResult:cdvResult callbackId:[command callbackId]];
    }
    
    [self checkECTAvailability:^(BOOL result){
        
        CDVPluginResult* cdvResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:result] ;
            [self.commandDelegate sendPluginResult:cdvResult callbackId:[command callbackId]];
    }];
    
}


-(void) initEctController:(NSString*) hostname {
    // Mobile ECT Configuration
    self.mobileECTController = [[OSMobileECTController alloc] initWithSuperView:_mobileECTView
                                                                     andWebView:self.webView
                                                                    forHostname:_hostname ];
    
    [self.mobileECTController addOnExitEvent:self withSelector:@selector(onExitECT)];
    
    [self.commandDelegate runInBackground:^{
    
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mobileECTController prepareForViewDidLoad];
        });
    }];
}

-(void)handleOpenECT:(CDVInvokedUrlCommand*)command {
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL skipEctHelper = [userDefaults boolForKey:@"OSAPPFEEDBACK_ECT_SKIP_HELPER"];
    
    [self.mobileECTController skipHelper:skipEctHelper];
    
    dispatch_block_t block = ^
    {
        [self lockToCurrentOrientation];

        [self.mobileECTController openECTNativeUI];
        [self.mobileECTView setHidden:NO];
    };
    
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
    
    if(command){
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:[command callbackId]];
    }
}

-(void)onExitECT{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self unlockOrientation];
        [self.mobileECTView setHidden:YES];
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:YES forKey:@"OSAPPFEEDBACK_ECT_SKIP_HELPER"];
    });
}

# pragma mark - Open gesture handling
-(void)registerGestureHandler{

    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleOpenGesture:)];
    [longPressRecognizer setMinimumPressDuration:0.6];
    [longPressRecognizer setNumberOfTouchesRequired:2];
    
    [self.webView addGestureRecognizer:longPressRecognizer];
    
}

-(void)handleOpenGesture:(UILongPressGestureRecognizer*) gestureRecognizer {
    if([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        
        if ([[CDVReachability reachabilityForInternetConnection]currentReachabilityStatus] != NotReachable){
            [self checkECTAvailability:^(BOOL result){
                if(result){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self handleOpenECT:nil];
                    });
                }
            }];
        }
        else{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Can't send feedback"
                                                                           message:@"Make sure your device has internet connection and try again."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            
            [self.viewController presentViewController:alert animated:YES completion:nil];
        }
    }
}

@end
